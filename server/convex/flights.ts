import { v } from "convex/values";
import { query, mutation } from "./_generated/server";
import { getAuthenticatedUserId, verifyTripOwnership } from "./lib/auth";

// Get all flights for a trip (requires ownership)
export const listByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    return await ctx.db
      .query("flights")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();
  },
});

// Get a single flight by ID
export const get = query({
  args: { id: v.id("flights") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const flight = await ctx.db.get(args.id);
    if (!flight) return null;

    // Verify user owns the parent trip
    await verifyTripOwnership(ctx, flight.tripId, userId);

    return flight;
  },
});

// Create a new flight (requires trip ownership)
export const create = mutation({
  args: {
    tripId: v.id("trips"),
    flightNumber: v.string(),
    airline: v.string(),
    departureAirportCode: v.string(),
    arrivalAirportCode: v.string(),
    departureDate: v.string(),
    departureTime: v.optional(v.string()),
    arrivalDate: v.optional(v.string()),
    arrivalTime: v.optional(v.string()),
    departureTerminal: v.optional(v.string()),
    arrivalTerminal: v.optional(v.string()),
    duration: v.optional(v.string()),
    cabinClass: v.optional(v.string()),
    seatNumber: v.optional(v.string()),
    baggageAllowance: v.optional(v.string()),
    aircraft: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    eTicketNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    const flightId = await ctx.db.insert("flights", args);
    return await ctx.db.get(flightId);
  },
});

// Update a flight (requires trip ownership)
export const update = mutation({
  args: {
    id: v.id("flights"),
    flightNumber: v.optional(v.string()),
    airline: v.optional(v.string()),
    departureAirportCode: v.optional(v.string()),
    arrivalAirportCode: v.optional(v.string()),
    departureDate: v.optional(v.string()),
    departureTime: v.optional(v.string()),
    arrivalDate: v.optional(v.string()),
    arrivalTime: v.optional(v.string()),
    departureTerminal: v.optional(v.string()),
    arrivalTerminal: v.optional(v.string()),
    duration: v.optional(v.string()),
    cabinClass: v.optional(v.string()),
    seatNumber: v.optional(v.string()),
    baggageAllowance: v.optional(v.string()),
    aircraft: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    eTicketNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const { id, ...updates } = args;

    const flight = await ctx.db.get(id);
    if (!flight) {
      throw new Error("Flight not found");
    }

    await verifyTripOwnership(ctx, flight.tripId, userId);

    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete a flight (requires trip ownership)
export const remove = mutation({
  args: { id: v.id("flights") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const flight = await ctx.db.get(args.id);
    if (!flight) {
      throw new Error("Flight not found");
    }

    await verifyTripOwnership(ctx, flight.tripId, userId);

    await ctx.db.delete(args.id);
    return { message: "Flight deleted" };
  },
});
