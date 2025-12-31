import { Hono } from "hono";
import { db } from "../db";
import { activities } from "../db/schema";
import { eq } from "drizzle-orm";

const app = new Hono();

// Nested under /api/trips/:tripId/activities
app.get("/trips/:tripId/activities", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const result = await db
    .select()
    .from(activities)
    .where(eq(activities.tripId, tripId));
  return c.json(result);
});

app.post("/trips/:tripId/activities", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const body = await c.req.json();
  const newActivity = await db
    .insert(activities)
    .values({ ...body, tripId })
    .returning();
  return c.json(newActivity[0], 201);
});

// Direct /api/activities/:id
app.get("/activities/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const result = await db
    .select()
    .from(activities)
    .where(eq(activities.id, id));
  if (result.length === 0) {
    return c.json({ error: "Activity not found" }, 404);
  }
  return c.json(result[0]);
});

app.put("/activities/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json();
  const updated = await db
    .update(activities)
    .set(body)
    .where(eq(activities.id, id))
    .returning();
  if (updated.length === 0) {
    return c.json({ error: "Activity not found" }, 404);
  }
  return c.json(updated[0]);
});

app.delete("/activities/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db
    .delete(activities)
    .where(eq(activities.id, id))
    .returning();
  if (deleted.length === 0) {
    return c.json({ error: "Activity not found" }, 404);
  }
  return c.json({ message: "Activity deleted" });
});

export default app;

