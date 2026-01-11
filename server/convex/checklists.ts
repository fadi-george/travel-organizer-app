import { v } from "convex/values";
import { query, mutation } from "./_generated/server";
import { getAuthenticatedUserId, verifyTripOwnership } from "./lib/auth";

// ============ SECTIONS ============

// Get all sections for a trip (ordered)
export const getSectionsByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    const sections = await ctx.db
      .query("checklistSections")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();

    return sections.sort((a, b) => a.order - b.order);
  },
});

// Get all sections with their items for a trip
export const getChecklistByTrip = query({
  args: { tripId: v.id("trips") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    const sections = await ctx.db
      .query("checklistSections")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();

    const sortedSections = sections.sort((a, b) => a.order - b.order);

    // Fetch items for each section
    const sectionsWithItems = await Promise.all(
      sortedSections.map(async (section) => {
        const items = await ctx.db
          .query("checklistItems")
          .withIndex("by_section", (q) => q.eq("sectionId", section._id))
          .collect();

        const sortedItems = items.sort((a, b) => a.order - b.order);

        return {
          ...section,
          items: sortedItems,
        };
      })
    );

    return sectionsWithItems;
  },
});

// Create a new section
export const createSection = mutation({
  args: {
    tripId: v.id("trips"),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    await verifyTripOwnership(ctx, args.tripId, userId);

    // Get the highest order number for this trip's sections
    const existingSections = await ctx.db
      .query("checklistSections")
      .withIndex("by_trip", (q) => q.eq("tripId", args.tripId))
      .collect();

    const maxOrder = existingSections.reduce(
      (max, section) => Math.max(max, section.order),
      -1
    );

    const sectionId = await ctx.db.insert("checklistSections", {
      tripId: args.tripId,
      name: args.name,
      order: maxOrder + 1,
    });

    return await ctx.db.get(sectionId);
  },
});

// Update a section (rename or reorder)
export const updateSection = mutation({
  args: {
    id: v.id("checklistSections"),
    name: v.optional(v.string()),
    order: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const { id, ...updates } = args;

    const section = await ctx.db.get(id);
    if (!section) {
      throw new Error("Section not found");
    }

    await verifyTripOwnership(ctx, section.tripId, userId);

    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete a section and all its items
export const deleteSection = mutation({
  args: { id: v.id("checklistSections") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const section = await ctx.db.get(args.id);
    if (!section) {
      throw new Error("Section not found");
    }

    await verifyTripOwnership(ctx, section.tripId, userId);

    // Delete all items in this section
    const items = await ctx.db
      .query("checklistItems")
      .withIndex("by_section", (q) => q.eq("sectionId", args.id))
      .collect();

    for (const item of items) {
      await ctx.db.delete(item._id);
    }

    // Delete the section
    await ctx.db.delete(args.id);
    return { message: "Section and items deleted" };
  },
});

// ============ ITEMS ============

// Get all items for a section
export const getItemsBySection = query({
  args: { sectionId: v.id("checklistSections") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);

    const section = await ctx.db.get(args.sectionId);
    if (!section) {
      throw new Error("Section not found");
    }

    await verifyTripOwnership(ctx, section.tripId, userId);

    const items = await ctx.db
      .query("checklistItems")
      .withIndex("by_section", (q) => q.eq("sectionId", args.sectionId))
      .collect();

    return items.sort((a, b) => a.order - b.order);
  },
});

// Create a new item
export const createItem = mutation({
  args: {
    sectionId: v.id("checklistSections"),
    text: v.string(),
    completed: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);

    const section = await ctx.db.get(args.sectionId);
    if (!section) {
      throw new Error("Section not found");
    }

    await verifyTripOwnership(ctx, section.tripId, userId);

    // Get the highest order number for this section's items
    const existingItems = await ctx.db
      .query("checklistItems")
      .withIndex("by_section", (q) => q.eq("sectionId", args.sectionId))
      .collect();

    const maxOrder = existingItems.reduce(
      (max, item) => Math.max(max, item.order),
      -1
    );

    const itemId = await ctx.db.insert("checklistItems", {
      sectionId: args.sectionId,
      text: args.text,
      completed: args.completed ?? false,
      order: maxOrder + 1,
    });

    return await ctx.db.get(itemId);
  },
});

// Update an item (toggle completed, edit text, reorder)
export const updateItem = mutation({
  args: {
    id: v.id("checklistItems"),
    text: v.optional(v.string()),
    completed: v.optional(v.boolean()),
    order: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const { id, ...updates } = args;

    const item = await ctx.db.get(id);
    if (!item) {
      throw new Error("Item not found");
    }

    const section = await ctx.db.get(item.sectionId);
    if (!section) {
      throw new Error("Section not found");
    }

    await verifyTripOwnership(ctx, section.tripId, userId);

    await ctx.db.patch(id, updates);
    return await ctx.db.get(id);
  },
});

// Delete an item
export const deleteItem = mutation({
  args: { id: v.id("checklistItems") },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);
    const item = await ctx.db.get(args.id);
    if (!item) {
      throw new Error("Item not found");
    }

    const section = await ctx.db.get(item.sectionId);
    if (!section) {
      throw new Error("Section not found");
    }

    await verifyTripOwnership(ctx, section.tripId, userId);

    await ctx.db.delete(args.id);
    return { message: "Item deleted" };
  },
});

// Reorder items in a single atomic mutation
export const reorderItems = mutation({
  args: {
    updates: v.array(
      v.object({
        id: v.id("checklistItems"),
        order: v.number(),
      })
    ),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);

    // Verify all items exist and user has access
    for (const update of args.updates) {
      const item = await ctx.db.get(update.id);
      if (!item) {
        throw new Error("Item not found");
      }
      const section = await ctx.db.get(item.sectionId);
      if (!section) {
        throw new Error("Section not found");
      }
      await verifyTripOwnership(ctx, section.tripId, userId);
    }

    // Apply all order updates
    for (const update of args.updates) {
      await ctx.db.patch(update.id, { order: update.order });
    }

    return { message: "Items reordered" };
  },
});

// Reorder sections in a single atomic mutation
export const reorderSections = mutation({
  args: {
    updates: v.array(
      v.object({
        id: v.id("checklistSections"),
        order: v.number(),
      })
    ),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthenticatedUserId(ctx);

    // Verify all sections exist and user has access
    for (const update of args.updates) {
      const section = await ctx.db.get(update.id);
      if (!section) {
        throw new Error("Section not found");
      }
      await verifyTripOwnership(ctx, section.tripId, userId);
    }

    // Apply all order updates
    for (const update of args.updates) {
      await ctx.db.patch(update.id, { order: update.order });
    }

    return { message: "Sections reordered" };
  },
});
