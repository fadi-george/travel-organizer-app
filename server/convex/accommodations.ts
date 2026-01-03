import { v } from "convex/values";
import { query, mutation } from "./_generated/server";
import { getAuthenticatedUserId, verifyTripOwnership } from "./lib/auth";

// Get all accommodations for a trip (requires ownership)
export const listByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

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
    const userId = await getAuthenticatedUserId(ctx);
    const accommodation = await ctx.db.get(args.id);
    if (!accommodation) return null;

    // Verify user owns the parent trip
    await verifyTripOwnership(ctx, accommodation.tripId, userId);

    return accommodation;
  },
});

// Create a new accommodation (requires trip ownership)
export const create = mutation({
  args: {
    tripId: v.id("trips"),
    hotelName: v.string(),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkInTime: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    checkOutTime: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    const accommodationId = await ctx.db.insert("accommodations", args);
    return await ctx.db.get(accommodationId);
  },
});

// Update an accommodation (requires trip ownership)
export const update = mutation({
  args: {
    id: v.id("accommodations"),
    hotelName: v.optional(v.string()),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkInTime: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    checkOutTime: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const { id, ...updates } = args;

    const accommodation = await ctx.db.get(id);
    if (!accommodation) {
      throw new Error("Accommodation not found");
    }

    await verifyTripOwnership(ctx, accommodation.tripId, userId);

    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete an accommodation (requires trip ownership)
export const remove = mutation({
  args: { id: v.id("accommodations") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const accommodation = await ctx.db.get(args.id);
    if (!accommodation) {
      throw new Error("Accommodation not found");
    }

    await verifyTripOwnership(ctx, accommodation.tripId, userId);

    await ctx.db.delete(args.id);
    return { message: "Accommodation deleted" };
  },
});
