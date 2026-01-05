import type { QueryCtx, MutationCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";

/**
 * Get the authenticated user's Convex ID from the users table.
 * Throws an error if not authenticated or user not found.
 */
export async function getAuthenticatedUserId(
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
    throw new Error("User not found in database");
  }

  return user._id;
}

/**
 * Get the authenticated user's Convex ID if available, or null if not authenticated.
 */
export async function getOptionalUserId(
  ctx: QueryCtx | MutationCtx
): Promise<Id<"users"> | null> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    return null;
  }

  const user = await ctx.db
    .query("users")
    .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
    .unique();

  return user?._id ?? null;
}

/**
 * Verify that the authenticated user owns the given trip.
 * Throws an error if not authorized.
 */
export async function verifyTripOwnership(
  ctx: QueryCtx | MutationCtx,
  tripId: Id<"trips">,
  userId: Id<"users">
): Promise<void> {
  const trip = await ctx.db.get(tripId);
  if (!trip) {
    throw new Error("Trip not found");
  }
  if (trip.userId !== userId) {
    throw new Error("Not authorized to access this trip");
  }
}

