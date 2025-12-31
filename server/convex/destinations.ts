import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

// Get all destinations for a trip
export const listByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("destinations")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();
  },
});

// Get a single destination by ID with accommodations
export const get = query({
  args: { id: v.id("destinations") },
  handler: async (ctx, args) => {
    const destination = await ctx.db.get(args.id);
    if (!destination) return null;

    const accommodations = await ctx.db
      .query("accommodations")
      .withIndex("by_destination", (q) => q.eq("destinationId", destination._id))
      .collect();

    return { ...destination, accommodations };
  },
});

// Create a new destination
export const create = mutation({
  args: {
    tripId: v.id("trips"),
    country: v.string(),
    arrivalDate: v.optional(v.string()),
    departureDate: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Verify trip exists
    const trip = await ctx.db.get(args.tripId);
    if (!trip) {
      throw new Error("Trip not found");
    }
    const destinationId = await ctx.db.insert("destinations", args);
    return await ctx.db.get(destinationId);
  },
});

// Update a destination
export const update = mutation({
  args: {
    id: v.id("destinations"),
    country: v.optional(v.string()),
    arrivalDate: v.optional(v.string()),
    departureDate: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { id, ...updates } = args;
    const existing = await ctx.db.get(id);
    if (!existing) {
      throw new Error("Destination not found");
    }
    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete a destination (cascades to accommodations)
export const remove = mutation({
  args: { id: v.id("destinations") },
  handler: async (ctx, args) => {
    const destination = await ctx.db.get(args.id);
    if (!destination) {
      throw new Error("Destination not found");
    }

    // Delete related accommodations
    const accommodations = await ctx.db
      .query("accommodations")
      .withIndex("by_destination", (q) => q.eq("destinationId", args.id))
      .collect();
    for (const accommodation of accommodations) {
      await ctx.db.delete(accommodation._id);
    }

    await ctx.db.delete(args.id);
    return { message: "Destination deleted" };
  },
});

