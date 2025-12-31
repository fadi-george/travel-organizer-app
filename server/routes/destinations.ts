import { Hono } from "hono";
import { db } from "../db";
import { destinations } from "../db/schema";
import { eq } from "drizzle-orm";

const app = new Hono();

// Nested under /api/trips/:tripId/destinations
app.get("/trips/:tripId/destinations", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const result = await db
    .select()
    .from(destinations)
    .where(eq(destinations.tripId, tripId));
  return c.json(result);
});

app.post("/trips/:tripId/destinations", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const body = await c.req.json();
  const newDestination = await db
    .insert(destinations)
    .values({ ...body, tripId })
    .returning();
  return c.json(newDestination[0], 201);
});

// Direct /api/destinations/:id
app.get("/destinations/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const destination = await db.query.destinations.findFirst({
    where: eq(destinations.id, id),
    with: {
      accommodations: true,
    },
  });
  if (!destination) {
    return c.json({ error: "Destination not found" }, 404);
  }
  return c.json(destination);
});

app.put("/destinations/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json();
  const updated = await db
    .update(destinations)
    .set(body)
    .where(eq(destinations.id, id))
    .returning();
  if (updated.length === 0) {
    return c.json({ error: "Destination not found" }, 404);
  }
  return c.json(updated[0]);
});

app.delete("/destinations/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db
    .delete(destinations)
    .where(eq(destinations.id, id))
    .returning();
  if (deleted.length === 0) {
    return c.json({ error: "Destination not found" }, 404);
  }
  return c.json({ message: "Destination deleted" });
});

export default app;

