import { v } from "convex/values";
import { query, mutation } from "./_generated/server";
import { getAuthenticatedUserId, verifyTripOwnership } from "./lib/auth";

// Get all activities for a trip (requires ownership)
export const listByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    return await ctx.db
      .query("activities")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();
  },
});

// Get a single activity by ID
export const get = query({
  args: { id: v.id("activities") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const activity = await ctx.db.get(args.id);
    if (!activity) return null;

    // Verify user owns the parent trip
    await verifyTripOwnership(ctx, activity.tripId, userId);

    return activity;
  },
});

// Create a new activity (requires trip ownership)
export const create = mutation({
  args: {
    tripId: v.id("trips"),
    date: v.string(),
    time: v.optional(v.string()),
    title: v.string(),
    location: v.optional(v.string()),
    type: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    const activityId = await ctx.db.insert("activities", args);
    return await ctx.db.get(activityId);
  },
});

// Update an activity (requires trip ownership)
export const update = mutation({
  args: {
    id: v.id("activities"),
    date: v.optional(v.string()),
    time: v.optional(v.string()),
    title: v.optional(v.string()),
    location: v.optional(v.string()),
    type: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const { id, ...updates } = args;

    const activity = await ctx.db.get(id);
    if (!activity) {
      throw new Error("Activity not found");
    }

    await verifyTripOwnership(ctx, activity.tripId, userId);

    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete an activity (requires trip ownership)
export const remove = mutation({
  args: { id: v.id("activities") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const activity = await ctx.db.get(args.id);
    if (!activity) {
      throw new Error("Activity not found");
    }

    await verifyTripOwnership(ctx, activity.tripId, userId);

    await ctx.db.delete(args.id);
    return { message: "Activity deleted" };
  },
});
