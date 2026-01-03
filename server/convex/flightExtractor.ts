import { v } from "convex/values";
import { action, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  type ClaudeResponse,
  parseClaudeJson,
  CLAUDE_MODEL,
  CLAUDE_MAX_TOKENS,
} from "./lib/parseClaudeJson";

// Internal mutation to save extracted flights
export const saveExtractedFlights = internalMutation({
  args: {
    tripId: v.id("trips"),
    flights: v.array(
      v.object({
        flightNumber: v.string(),
        airline: v.string(),
        departureAirportCode: v.string(),
        arrivalAirportCode: v.string(),
        departureDate: v.string(),
        departureTime: v.optional(v.string()),
        arrivalDate: v.optional(v.string()),
        arrivalTime: v.optional(v.string()),
        departureTerminal: v.optional(v.string()),
        arrivalTerminal: v.optional(v.string()),
        confirmationNumber: v.optional(v.string()),
        seatNumber: v.optional(v.string()),
        cabinClass: v.optional(v.string()),
        baggageAllowance: v.optional(v.string()),
        aircraft: v.optional(v.string()),
        duration: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const trip = await ctx.db.get(args.tripId);
    if (!trip) {
      throw new Error("Trip not found");
    }

    // Get existing flights for this trip to check for duplicates
    const existingFlights = await ctx.db
      .query("flights")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();

    const savedFlights = [];
    for (const flight of args.flights) {
      // Check if flight already exists (same flight number and departure date)
      const existingFlight = existingFlights.find(
        (existing) =>
          existing.flightNumber === flight.flightNumber &&
          existing.departureDate === flight.departureDate
      );

      if (existingFlight) {
        // Update existing flight with new data (merge, keeping existing values if new ones are undefined)
        const updates: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(flight)) {
          if (value !== undefined && value !== null && value !== "") {
            updates[key] = value;
          }
        }
        await ctx.db.patch(existingFlight._id, updates);
        const updatedFlight = await ctx.db.get(existingFlight._id);
        savedFlights.push(updatedFlight);
      } else {
        const flightId = await ctx.db.insert("flights", {
          tripId: args.tripId,
          ...flight,
        });
        const savedFlight = await ctx.db.get(flightId);
        savedFlights.push(savedFlight);
      }
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
    // Verify user is authenticated
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return { success: false, error: "Not authenticated" };
    }

    const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
    if (!anthropicApiKey) {
      throw new Error("ANTHROPIC_API_KEY environment variable is not set");
    }

    const extractionPrompt = `Extract flights from this PDF. Return JSON only:
{"flights":[{
  "flightNumber":"AA123",
  "airline":"American Airlines",
  "departureAirportCode":"LAX",
  "arrivalAirportCode":"SIN",
  "departureDate":"YYYY-MM-DD",
  "departureTime":"HH:MM"|null,
  "arrivalDate":"YYYY-MM-DD"|null,
  "arrivalTime":"HH:MM"|null,
  "departureTerminal":string|null,
  "arrivalTerminal":string|null,
  "confirmationNumber":string|null,
  "seatNumber":string|null,
  "cabinClass":"Economy"|"Business"|"First"|null,
  "baggageAllowance":string|null,
  "aircraft":string|null,
  "duration":string|null
}]}
Rules: JSON only. Dates=YYYY-MM-DD. Times=HH:MM 24h. Airport codes=3-letter IATA (required). No flights={"flights":[]}`;

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": anthropicApiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: CLAUDE_MODEL,
          max_tokens: CLAUDE_MAX_TOKENS,
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

      const result = (await response.json()) as ClaudeResponse;

      const content = result.content?.[0];

      if (!content || content.type !== "text") {
        throw new Error("Unexpected response format from Claude");
      }

      // Parse the JSON response
      const extractedData = parseClaudeJson<{
        flights?: Array<Record<string, unknown>>;
      }>(content.text);

      if (!extractedData.flights || !Array.isArray(extractedData.flights)) {
        return { success: true, flights: [] };
      }

      // Validate and clean the extracted flights
      const validFlights = extractedData.flights
        .filter(
          (f: Record<string, unknown>) =>
            f.flightNumber &&
            f.airline &&
            f.departureAirportCode &&
            f.arrivalAirportCode &&
            f.departureDate
        )
        .map((f: Record<string, unknown>) => ({
          flightNumber: String(f.flightNumber),
          airline: String(f.airline),
          departureAirportCode: String(f.departureAirportCode).toUpperCase(),
          arrivalAirportCode: String(f.arrivalAirportCode).toUpperCase(),
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
          baggageAllowance: f.baggageAllowance
            ? String(f.baggageAllowance)
            : undefined,
          aircraft: f.aircraft ? String(f.aircraft) : undefined,
          duration: f.duration ? String(f.duration) : undefined,
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
