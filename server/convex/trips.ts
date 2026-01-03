import { v } from "convex/values";
import { query, mutation } from "./_generated/server";
import type { QueryCtx, MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";

/**
 * Helper to get the authenticated user's Convex document ID.
 * Throws an error if not authenticated or user not found.
 */
async function getAuthenticatedUserId(
  ctx: QueryCtx | MutationCtx
): Promise<Id<"users">> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new Error("Not authenticated");
  }
  const user = await ctx.db
    .query("users")
    .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
    .unique();
  if (!user) {
    throw new Error("User not found");
  }
  return user._id;
}

/**
 * Helper to verify the user owns a trip.
 * Returns the trip if authorized, throws if not.
 */
async function verifyTripOwnership(
  ctx: QueryCtx | MutationCtx,
  tripId: Id<"trips">,
  userId: Id<"users">
) {
  const trip = await ctx.db.get(tripId);
  if (!trip) {
    throw new Error("Trip not found");
  }
  if (trip.userId !== userId) {
    throw new Error("Not authorized to access this trip");
  }
  return trip;
}

// Get all trips for the authenticated user with related data
export const list = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return [];
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .unique();
    if (!user) {
      return [];
    }

    const trips = await ctx.db
      .query("trips")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();

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

// Get a single trip by ID (must be owned by authenticated user)
export const get = query({
  args: { id: v.id("trips") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .unique();
    if (!user) {
      return null;
    }

    const trip = await ctx.db.get(args.id);
    if (!trip) return null;

    // Verify ownership
    if (trip.userId !== user._id) {
      return null;
    }

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

// Create a new trip for the authenticated user
export const create = mutation({
  args: {
    name: v.string(),
    startDate: v.string(),
    endDate: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);

    const tripId = await ctx.db.insert("trips", {
      ...args,
      userId,
    });
    return await ctx.db.get(tripId);
  },
});

// Update a trip (must be owned by authenticated user)
export const update = mutation({
  args: {
    id: v.id("trips"),
    name: v.optional(v.string()),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const { id, ...updates } = args;

    await verifyTripOwnership(ctx, id, userId);

    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete a trip (cascades to accommodations, flights, activities)
export const remove = mutation({
  args: { id: v.id("trips") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.id, userId);

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
