import { Hono } from "hono";
import { db } from "../db";
import { flights } from "../db/schema";
import { eq } from "drizzle-orm";

const app = new Hono();

// Nested under /api/trips/:tripId/flights
app.get("/trips/:tripId/flights", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const result = await db
    .select()
    .from(flights)
    .where(eq(flights.tripId, tripId));
  return c.json(result);
});

app.post("/trips/:tripId/flights", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const body = await c.req.json();
  const newFlight = await db
    .insert(flights)
    .values({ ...body, tripId })
    .returning();
  return c.json(newFlight[0], 201);
});

// Direct /api/flights/:id
app.get("/flights/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const result = await db.select().from(flights).where(eq(flights.id, id));
  if (result.length === 0) {
    return c.json({ error: "Flight not found" }, 404);
  }
  return c.json(result[0]);
});

app.put("/flights/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json();
  const updated = await db
    .update(flights)
    .set(body)
    .where(eq(flights.id, id))
    .returning();
  if (updated.length === 0) {
    return c.json({ error: "Flight not found" }, 404);
  }
  return c.json(updated[0]);
});

app.delete("/flights/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db
    .delete(flights)
    .where(eq(flights.id, id))
    .returning();
  if (deleted.length === 0) {
    return c.json({ error: "Flight not found" }, 404);
  }
  return c.json({ message: "Flight deleted" });
});

export default app;
