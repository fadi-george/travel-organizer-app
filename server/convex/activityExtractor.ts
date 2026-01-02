import { v } from "convex/values";
import { action, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  type ClaudeResponse,
  parseClaudeJson,
  CLAUDE_MODEL,
  CLAUDE_MAX_TOKENS,
} from "./lib/parseClaudeJson";

// Internal mutation to save extracted activities
export const saveExtractedActivities = internalMutation({
  args: {
    tripId: v.id("trips"),
    activities: v.array(
      v.object({
        title: v.string(),
        date: v.string(),
        time: v.optional(v.string()),
        location: v.optional(v.string()),
        type: v.optional(v.string()),
        notes: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const trip = await ctx.db.get(args.tripId);
    if (!trip) {
      throw new Error("Trip not found");
    }

    // Get existing activities for this trip to check for duplicates
    const existingActivities = await ctx.db
      .query("activities")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();

    const savedActivities = [];
    for (const activity of args.activities) {
      // Check if activity already exists (same title and date)
      const existingActivity = existingActivities.find(
        (existing) =>
          existing.title === activity.title && existing.date === activity.date
      );

      if (existingActivity) {
        // Update existing activity with new data
        const updates: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(activity)) {
          if (value !== undefined && value !== null && value !== "") {
            updates[key] = value;
          }
        }
        await ctx.db.patch(existingActivity._id, updates);
        const updatedActivity = await ctx.db.get(existingActivity._id);
        savedActivities.push(updatedActivity);
      } else {
        const activityId = await ctx.db.insert("activities", {
          tripId: args.tripId,
          ...activity,
        });
        const savedActivity = await ctx.db.get(activityId);
        savedActivities.push(savedActivity);
      }
    }

    return savedActivities;
  },
});

// Action to process PDF and extract activity information using Claude
export const extractActivitiesFromPdf = action({
  args: {
    tripId: v.id("trips"),
    pdfBase64: v.string(),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    success: boolean;
    activities?: unknown[];
    error?: string;
  }> => {
    const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
    if (!anthropicApiKey) {
      throw new Error("ANTHROPIC_API_KEY environment variable is not set");
    }

    const validTypes = [
      "Sightseeing",
      "Food & Dining",
      "Entertainment",
      "Shopping",
      "Tour",
      "Transportation",
      "Relaxation",
      "Adventure",
      "Cultural",
      "Nature",
      "Other",
    ];

    const extractionPrompt = `Extract activities from this PDF as JSON. Return ONLY valid JSON, no markdown.

Format: {"activities": [{"title": "string", "date": "YYYY-MM-DD", "time": "HH:MM or null", "location": "full Google Maps address or null", "type": "one of: ${validTypes.join(", ")} or null", "notes": "string or null"}]}

Rules:
- SKIP flights and hotel transfers/check-ins/check-outs (handled separately)
- SPLIT titles with commas into separate entries (e.g., "Grand Palace, Wat Pho" → 2 activities)
- Use clean titles (e.g., "Visit Grand Palace" not just "Grand Palace")
- MEALS: Extract as "Food & Dining". Default times: breakfast 08:00, lunch 12:00, dinner 19:00. For generic locations use simple titles (e.g., "Lunch" not "Lunch at the local restaurant"), but keep specific names (e.g., "Dinner at Le Cinq")
- Type mapping: museums→Cultural, spas→Relaxation, hiking/diving→Adventure, restaurants→Food & Dining
- For famous landmarks, include full address even if not in PDF
- 2-digit years → 20xx
- Return {"activities": []} if none found`;

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
        activities?: Array<Record<string, unknown>>;
      }>(content.text);

      if (
        !extractedData.activities ||
        !Array.isArray(extractedData.activities)
      ) {
        return { success: true, activities: [] };
      }

      // Validate and clean the extracted activities
      const validActivities = extractedData.activities
        .filter(
          (a: Record<string, unknown>) =>
            a.title && a.date && typeof a.date === "string"
        )
        .map((a: Record<string, unknown>) => ({
          title: String(a.title),
          date: String(a.date),
          time: a.time ? String(a.time) : undefined,
          location: a.location ? String(a.location) : undefined,
          type:
            a.type && validTypes.includes(String(a.type))
              ? String(a.type)
              : undefined,
          notes: a.notes ? String(a.notes) : undefined,
        }));

      if (validActivities.length === 0) {
        return { success: true, activities: [] };
      }

      // Save the activities to the database
      const savedActivities = await ctx.runMutation(
        internal.activityExtractor.saveExtractedActivities,
        {
          tripId: args.tripId,
          activities: validActivities,
        }
      );

      return { success: true, activities: savedActivities };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      console.error("Error extracting activities from PDF:", errorMessage);
      return { success: false, error: errorMessage };
    }
  },
});
