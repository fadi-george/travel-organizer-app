import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

// Get all accommodations for a trip
export const listByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("accommodations")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();
  },
});

// Get a single accommodation by ID
export const get = query({
  args: { id: v.id("accommodations") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.id);
  },
});

// Create a new accommodation
export const create = mutation({
  args: {
    tripId: v.id("trips"),
    hotelName: v.string(),
    city: v.optional(v.string()),
    country: v.optional(v.string()),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Verify trip exists
    const trip = await ctx.db.get(args.tripId);
    if (!trip) {
      throw new Error("Trip not found");
    }
    const accommodationId = await ctx.db.insert("accommodations", args);
    return await ctx.db.get(accommodationId);
  },
});

// Update an accommodation
export const update = mutation({
  args: {
    id: v.id("accommodations"),
    hotelName: v.optional(v.string()),
    city: v.optional(v.string()),
    country: v.optional(v.string()),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { id, ...updates } = args;
    const existing = await ctx.db.get(id);
    if (!existing) {
      throw new Error("Accommodation not found");
    }
    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete an accommodation
export const remove = mutation({
  args: { id: v.id("accommodations") },
  handler: async (ctx, args) => {
    const accommodation = await ctx.db.get(args.id);
    if (!accommodation) {
      throw new Error("Accommodation not found");
    }
    await ctx.db.delete(args.id);
    return { message: "Accommodation deleted" };
  },
});
