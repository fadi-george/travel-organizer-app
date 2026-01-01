import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

// Get all trips with related data
export const list = query({
  args: {},
  handler: async (ctx) => {
    const trips = await ctx.db.query("trips").collect();

    // Fetch related data for each trip
    const tripsWithRelations = await Promise.all(
      trips.map(async (trip) => {
        const accommodations = await ctx.db
          .query("accommodations")
          .withIndex("by_trip", (q) => q.eq("tripId", trip._id))
          .collect();

        const flights = await ctx.db
          .query("flights")
          .withIndex("by_trip", (q) => q.eq("tripId", trip._id))
          .collect();

        const activities = await ctx.db
          .query("activities")
          .withIndex("by_trip", (q) => q.eq("tripId", trip._id))
          .collect();

        return {
          ...trip,
          accommodations,
          flights,
          activities,
        };
      })
    );

    return tripsWithRelations;
  },
});

// Get a single trip by ID
export const get = query({
  args: { id: v.id("trips") },
  handler: async (ctx, args) => {
    const trip = await ctx.db.get(args.id);
    if (!trip) return null;

    const accommodations = await ctx.db
      .query("accommodations")
      .withIndex("by_trip", (q) => q.eq("tripId", trip._id))
      .collect();

    const flights = await ctx.db
      .query("flights")
      .withIndex("by_trip", (q) => q.eq("tripId", trip._id))
      .collect();

    const activities = await ctx.db
      .query("activities")
      .withIndex("by_trip", (q) => q.eq("tripId", trip._id))
      .collect();

    return {
      ...trip,
      accommodations,
      flights,
      activities,
    };
  },
});

// Create a new trip
export const create = mutation({
  args: {
    name: v.string(),
    startDate: v.string(),
    endDate: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const tripId = await ctx.db.insert("trips", args);
    return await ctx.db.get(tripId);
  },
});

// Update a trip
export const update = mutation({
  args: {
    id: v.id("trips"),
    name: v.optional(v.string()),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { id, ...updates } = args;
    const existing = await ctx.db.get(id);
    if (!existing) {
      throw new Error("Trip not found");
    }
    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete a trip (cascades to accommodations, flights, activities)
export const remove = mutation({
  args: { id: v.id("trips") },
  handler: async (ctx, args) => {
    const trip = await ctx.db.get(args.id);
    if (!trip) {
      throw new Error("Trip not found");
    }

    // Delete related accommodations
    const accommodations = await ctx.db
      .query("accommodations")
      .withIndex("by_trip", (q) => q.eq("tripId", args.id))
      .collect();
    for (const accommodation of accommodations) {
      await ctx.db.delete(accommodation._id);
    }

    // Delete related flights
    const flights = await ctx.db
      .query("flights")
      .withIndex("by_trip", (q) => q.eq("tripId", args.id))
      .collect();
    for (const flight of flights) {
      await ctx.db.delete(flight._id);
    }

    // Delete related activities
    const activities = await ctx.db
      .query("activities")
      .withIndex("by_trip", (q) => q.eq("tripId", args.id))
      .collect();
    for (const activity of activities) {
      await ctx.db.delete(activity._id);
    }

    // Delete the trip
    await ctx.db.delete(args.id);
    return { message: "Trip deleted" };
  },
});
