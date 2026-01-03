import { Migrations } from "@convex-dev/migrations";
import { components, internal } from "./_generated/api";
import type { DataModel } from "./_generated/dataModel";

export const migrations = new Migrations<DataModel>(components.migrations);
export const run = migrations.runner();

// Migration: Backfill startDate and endDate for trips that don't have them
export const backfillTripDates = migrations.define({
  table: "trips",
  migrateOne: async (ctx, trip) => {
    // Only update if dates are missing
    if (trip.startDate === undefined || trip.endDate === undefined) {
      // Set default dates (today and a week from today)
      const today = new Date();
      const nextWeek = new Date(today);
      nextWeek.setDate(nextWeek.getDate() + 7);

      await ctx.db.patch(trip._id, {
        startDate: trip.startDate ?? today.toISOString().split("T")[0],
        endDate: trip.endDate ?? nextWeek.toISOString().split("T")[0],
      });
    }
  },
});

// Migration: Backfill userId for existing trips (assigns to a default/anonymous user)
// After running this migration, you can make userId required again in schema.ts
export const backfillTripUserId = migrations.define({
  table: "trips",
  migrateOne: async (ctx, trip) => {
    if (trip.userId === undefined) {
      // Assign to a placeholder user ID for legacy trips
      // These trips will be accessible to anyone until claimed or deleted
      await ctx.db.patch(trip._id, {
        userId: "legacy_user",
      });
    }
  },
});

// Migration: Convert trip.userId from Clerk ID string to Convex user document Id
// After running: change schema.ts trips.userId back to v.id("users")
export const migrateTripsUserIdToRef = migrations.define({
  table: "trips",
  migrateOne: async (ctx, trip) => {
    const userId = trip.userId;
    // Skip if already a Convex ID (starts with typical Convex ID pattern)
    if (!userId || userId.startsWith("j")) {
      return;
    }
    // Look up user by clerkId
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", userId))
      .unique();
    if (user) {
      await ctx.db.patch(trip._id, { userId: user._id });
    }
  },
});
