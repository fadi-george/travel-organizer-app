import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

// Get all accommodations for a destination
export const listByDestination = query({
  args: { destinationId: v.id("destinations") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("accommodations")
      .withIndex("by_destination", (q) =>
        q.eq("destinationId", args.destinationId)
      )
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
    destinationId: v.id("destinations"),
    hotelName: v.string(),
    city: v.optional(v.string()),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Verify destination exists
    const destination = await ctx.db.get(args.destinationId);
    if (!destination) {
      throw new Error("Destination not found");
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

