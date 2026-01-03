import { v } from "convex/values";
import { action, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  type ClaudeResponse,
  parseClaudeJson,
  CLAUDE_MODEL,
  CLAUDE_MAX_TOKENS,
} from "./lib/parseClaudeJson";

// Internal mutation to save extracted accommodations
export const saveExtractedAccommodations = internalMutation({
  args: {
    tripId: v.id("trips"),
    accommodations: v.array(
      v.object({
        hotelName: v.string(),
        city: v.optional(v.string()),
        country: v.optional(v.string()),
        roomType: v.optional(v.string()),
        checkIn: v.optional(v.string()),
        checkInTime: v.optional(v.string()),
        checkOut: v.optional(v.string()),
        checkOutTime: v.optional(v.string()),
        address: v.optional(v.string()),
        confirmationNumber: v.optional(v.string()),
        notes: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const trip = await ctx.db.get(args.tripId);
    if (!trip) {
      throw new Error("Trip not found");
    }

    // Get existing accommodations for this trip to check for duplicates
    const existingAccommodations = await ctx.db
      .query("accommodations")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();

    const savedAccommodations = [];
    for (const accommodation of args.accommodations) {
      // Check if accommodation already exists (same hotel name and check-in date)
      const existingAccommodation = existingAccommodations.find(
        (existing) =>
          existing.hotelName === accommodation.hotelName &&
          existing.checkIn === accommodation.checkIn
      );

      if (existingAccommodation) {
        // Update existing accommodation with new data (merge, keeping existing values if new ones are undefined)
        const updates: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(accommodation)) {
          if (value !== undefined && value !== null && value !== "") {
            updates[key] = value;
          }
        }
        await ctx.db.patch(existingAccommodation._id, updates);
        const updatedAccommodation = await ctx.db.get(
          existingAccommodation._id
        );
        savedAccommodations.push(updatedAccommodation);
      } else {
        const accommodationId = await ctx.db.insert("accommodations", {
          tripId: args.tripId,
          ...accommodation,
        });
        const savedAccommodation = await ctx.db.get(accommodationId);
        savedAccommodations.push(savedAccommodation);
      }
    }

    return savedAccommodations;
  },
});

// Action to process PDF and extract accommodation information using Claude
export const extractAccommodationsFromPdf = action({
  args: {
    tripId: v.id("trips"),
    pdfBase64: v.string(),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    success: boolean;
    accommodations?: unknown[];
    error?: string;
  }> => {
    // Verify user is authenticated
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return { success: false, error: "Not authenticated" };
    }

    const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
    if (!anthropicApiKey) {
      throw new Error("ANTHROPIC_API_KEY environment variable is not set");
    }

    const extractionPrompt = `Extract hotel bookings from this PDF as JSON:
{"accommodations":[{hotelName,roomType,checkIn,checkInTime,checkOut,checkOutTime,address,confirmationNumber,notes}]}

Rules:
- Dates: YYYY-MM-DD format. "13-16 Jan 26" → checkIn:2026-01-13, checkOut:2026-01-16
- Times: HH:MM format. Default checkIn:15:00, checkOut:11:00
- 2-digit years = 20xx
- address: Full Google Maps format (street, city, country)
- Include nights count in notes
- Use null for unknown fields
- Return ONLY valid JSON`;

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
        accommodations?: Array<Record<string, unknown>>;
      }>(content.text);

      if (
        !extractedData.accommodations ||
        !Array.isArray(extractedData.accommodations)
      ) {
        return { success: true, accommodations: [] };
      }

      // Validate and clean the extracted accommodations
      const validAccommodations = extractedData.accommodations
        .filter((a: Record<string, unknown>) => a.hotelName)
        .map((a: Record<string, unknown>) => ({
          hotelName: String(a.hotelName),
          city: a.city ? String(a.city) : undefined,
          country: a.country ? String(a.country) : undefined,
          roomType: a.roomType ? String(a.roomType) : undefined,
          checkIn: a.checkIn ? String(a.checkIn) : undefined,
          checkInTime: a.checkInTime ? String(a.checkInTime) : undefined,
          checkOut: a.checkOut ? String(a.checkOut) : undefined,
          checkOutTime: a.checkOutTime ? String(a.checkOutTime) : undefined,
          address: a.address ? String(a.address) : undefined,
          confirmationNumber: a.confirmationNumber
            ? String(a.confirmationNumber)
            : undefined,
          notes: a.notes ? String(a.notes) : undefined,
        }));

      if (validAccommodations.length === 0) {
        return { success: true, accommodations: [] };
      }

      // Save the accommodations to the database
      const savedAccommodations = await ctx.runMutation(
        internal.accommodationExtractor.saveExtractedAccommodations,
        {
          tripId: args.tripId,
          accommodations: validAccommodations,
        }
      );

      return { success: true, accommodations: savedAccommodations };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      console.error("Error extracting accommodations from PDF:", errorMessage);
      return { success: false, error: errorMessage };
    }
  },
});
