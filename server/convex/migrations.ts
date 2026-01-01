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
