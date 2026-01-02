import { v } from "convex/values";
import { action, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";

interface ClaudeResponse {
  content?: Array<{ type: string; text: string }>;
}

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

    const extractionPrompt = `Analyze this PDF document and extract all activities, tours, reservations, and planned events.
For each activity found, extract the following details in JSON format:

{
  "activities": [
    {
      "title": "string (e.g., 'Visit Eiffel Tower', 'Dinner at Le Cinq', 'City Walking Tour')",
      "date": "string (ISO format: YYYY-MM-DD)",
      "time": "string (24-hour format: HH:MM, e.g., '14:30') or null",
      "location": "string (full address suitable for Google Maps, e.g., 'Grand Palace, Na Phra Lan Rd, Phra Borom Maha Ratchawang, Bangkok, Thailand') or null",
      "type": "string (one of: ${validTypes.join(", ")}) or null",
      "notes": "string (any additional details like duration, confirmation numbers, tickets) or null"
    }
  ]
}

Important:
- Return ONLY valid JSON, no additional text
- If no activities are found, return {"activities": []}
- Convert all dates to ISO format (YYYY-MM-DD)
- Convert times to 24-hour format (HH:MM)
- Handle 2-digit years by assuming 20xx
- SPLIT COMPOUND ACTIVITIES: If a title contains multiple destinations/places separated by commas or "and" (e.g., "Flower Market, Grand Palace, Wat Pho"), create SEPARATE activity entries for each distinct place/attraction with the same date
- Each split activity should have a clean, simple title (e.g., "Visit Grand Palace" instead of "Grand Palace")
- Classify each activity with the most appropriate type from the list
- Include restaurant reservations as "Food & Dining"
- Include museum/gallery visits as "Cultural"
- Include spa appointments as "Relaxation"
- Include hiking, diving, etc. as "Adventure"
- For location, provide a full Google Maps-compatible address when possible (include venue name, street, city, country)
- If you know the actual address of a famous landmark/attraction, include it even if not in the PDF
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

      const result = (await response.json()) as ClaudeResponse;

      const content = result.content?.[0];

      if (!content || content.type !== "text") {
        throw new Error("Unexpected response format from Claude");
      }

      // Parse the JSON response
      let extractedData;
      try {
        const jsonMatch = content.text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
          throw new Error("No JSON found in response");
        }
        extractedData = JSON.parse(jsonMatch[0]);
      } catch {
        throw new Error(`Failed to parse Claude response: ${content.text}`);
      }

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
