import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

/**
 * Get the current authenticated user from the database.
 * Returns null if not authenticated or user not found.
 */
export const current = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .unique();

    return user;
  },
});

/**
 * Store or update the current user in the database.
 * Called after authentication to sync user data from Clerk.
 */
export const store = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }

    // Check if user already exists
    const existingUser = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .unique();

    if (existingUser) {
      // Update existing user with latest info from Clerk
      await ctx.db.patch(existingUser._id, {
        email: identity.email,
        name: identity.name,
        imageUrl: identity.pictureUrl,
      });
      return existingUser._id;
    }

    // Create new user
    const userId = await ctx.db.insert("users", {
      clerkId: identity.subject,
      email: identity.email,
      name: identity.name,
      imageUrl: identity.pictureUrl,
    });

    return userId;
  },
});

/**
 * Get the current user's Clerk ID (subject).
 * Useful for functions that need the user ID without fetching the full user.
 */
export const getCurrentUserId = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }
    return identity.subject;
  },
});

