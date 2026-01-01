import { v } from "convex/values";
import { action, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";

// Internal mutation to save extracted flights
export const saveExtractedFlights = internalMutation({
  args: {
    tripId: v.id("trips"),
    flights: v.array(
      v.object({
        flightNumber: v.string(),
        airline: v.string(),
        departureCity: v.string(),
        arrivalCity: v.string(),
        departureDate: v.string(),
        departureTime: v.optional(v.string()),
        arrivalDate: v.optional(v.string()),
        arrivalTime: v.optional(v.string()),
        departureTerminal: v.optional(v.string()),
        arrivalTerminal: v.optional(v.string()),
        confirmationNumber: v.optional(v.string()),
        seatNumber: v.optional(v.string()),
        cabinClass: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const trip = await ctx.db.get(args.tripId);
    if (!trip) {
      throw new Error("Trip not found");
    }

    const savedFlights = [];
    for (const flight of args.flights) {
      const flightId = await ctx.db.insert("flights", {
        tripId: args.tripId,
        ...flight,
      });
      const savedFlight = await ctx.db.get(flightId);
      savedFlights.push(savedFlight);
    }

    return savedFlights;
  },
});

// Action to process PDF and extract flight information using Claude
export const extractFlightsFromPdf = action({
  args: {
    tripId: v.id("trips"),
    pdfBase64: v.string(),
  },
  handler: async (
    ctx,
    args
  ): Promise<{ success: boolean; flights?: unknown[]; error?: string }> => {
    const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
    if (!anthropicApiKey) {
      throw new Error("ANTHROPIC_API_KEY environment variable is not set");
    }

    const extractionPrompt = `Analyze this PDF document and extract all flight information. 
For each flight found, extract the following details in JSON format:

{
  "flights": [
    {
      "flightNumber": "string (e.g., 'AA123')",
      "airline": "string (e.g., 'American Airlines')",
      "departureCity": "string (city name or airport code)",
      "arrivalCity": "string (city name or airport code)",
      "departureDate": "string (ISO format: YYYY-MM-DD)",
      "departureTime": "string (24h format: HH:MM) or null",
      "arrivalDate": "string (ISO format: YYYY-MM-DD) or null",
      "arrivalTime": "string (24h format: HH:MM) or null",
      "departureTerminal": "string or null",
      "arrivalTerminal": "string or null",
      "confirmationNumber": "string or null",
      "seatNumber": "string or null",
      "cabinClass": "string (e.g., 'Economy', 'Business', 'First') or null"
    }
  ]
}

Important:
- Return ONLY valid JSON, no additional text
- If no flights are found, return {"flights": []}
- Convert all dates to ISO format (YYYY-MM-DD)
- Convert times to 24-hour format (HH:MM)
- Use null for any fields that cannot be determined`;

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": anthropicApiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 4096,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "document",
                  source: {
                    type: "base64",
                    media_type: "application/pdf",
                    data: args.pdfBase64,
                  },
                },
                {
                  type: "text",
                  text: extractionPrompt,
                },
              ],
            },
          ],
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Claude API error: ${response.status} - ${errorText}`);
      }

      const result = await response.json();
      const content = result.content?.[0];

      if (!content || content.type !== "text") {
        throw new Error("Unexpected response format from Claude");
      }

      // Parse the JSON response
      let extractedData;
      try {
        // Try to extract JSON from the response (in case there's any surrounding text)
        const jsonMatch = content.text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
          throw new Error("No JSON found in response");
        }
        extractedData = JSON.parse(jsonMatch[0]);
      } catch {
        throw new Error(`Failed to parse Claude response: ${content.text}`);
      }

      if (!extractedData.flights || !Array.isArray(extractedData.flights)) {
        return { success: true, flights: [] };
      }

      // Validate and clean the extracted flights
      const validFlights = extractedData.flights
        .filter(
          (f: Record<string, unknown>) =>
            f.flightNumber &&
            f.airline &&
            f.departureCity &&
            f.arrivalCity &&
            f.departureDate
        )
        .map((f: Record<string, unknown>) => ({
          flightNumber: String(f.flightNumber),
          airline: String(f.airline),
          departureCity: String(f.departureCity),
          arrivalCity: String(f.arrivalCity),
          departureDate: String(f.departureDate),
          departureTime: f.departureTime ? String(f.departureTime) : undefined,
          arrivalDate: f.arrivalDate ? String(f.arrivalDate) : undefined,
          arrivalTime: f.arrivalTime ? String(f.arrivalTime) : undefined,
          departureTerminal: f.departureTerminal
            ? String(f.departureTerminal)
            : undefined,
          arrivalTerminal: f.arrivalTerminal
            ? String(f.arrivalTerminal)
            : undefined,
          confirmationNumber: f.confirmationNumber
            ? String(f.confirmationNumber)
            : undefined,
          seatNumber: f.seatNumber ? String(f.seatNumber) : undefined,
          cabinClass: f.cabinClass ? String(f.cabinClass) : undefined,
        }));

      if (validFlights.length === 0) {
        return { success: true, flights: [] };
      }

      // Save the flights to the database
      const savedFlights = await ctx.runMutation(
        internal.flightExtractor.saveExtractedFlights,
        {
          tripId: args.tripId,
          flights: validFlights,
        }
      );

      return { success: true, flights: savedFlights };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      console.error("Error extracting flights from PDF:", errorMessage);
      return { success: false, error: errorMessage };
    }
  },
});
