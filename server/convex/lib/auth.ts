import type { QueryCtx, MutationCtx } from "../_generated/server";
import type { Id } from "../_generated/dataModel";

/**
 * Get the authenticated user's ID (Clerk subject).
 * Throws an error if not authenticated.
 */
export async function getAuthenticatedUserId(
  ctx: QueryCtx | MutationCtx
): Promise<string> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new Error("Not authenticated");
  }
  return identity.subject;
}

/**
 * Get the authenticated user's ID if available, or null if not authenticated.
 */
export async function getOptionalUserId(
  ctx: QueryCtx | MutationCtx
): Promise<string | null> {
  const identity = await ctx.auth.getUserIdentity();
  return identity?.subject ?? null;
}

/**
 * Verify that the authenticated user owns the given trip.
 * Throws an error if not authorized.
 */
export async function verifyTripOwnership(
  ctx: QueryCtx | MutationCtx,
  tripId: Id<"trips">,
  userId: string
): Promise<void> {
  const trip = await ctx.db.get(tripId);
  if (!trip) {
    throw new Error("Trip not found");
  }
  if (trip.userId !== userId) {
    throw new Error("Not authorized to access this trip");
  }
}

