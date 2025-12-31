import { Hono } from "hono";
import { db } from "../db";
import { accommodations } from "../db/schema";
import { eq } from "drizzle-orm";

const app = new Hono();

// Nested under /api/destinations/:destinationId/accommodations
app.get("/destinations/:destinationId/accommodations", async (c) => {
  const destinationId = Number(c.req.param("destinationId"));
  const result = await db
    .select()
    .from(accommodations)
    .where(eq(accommodations.destinationId, destinationId));
  return c.json(result);
});

app.post("/destinations/:destinationId/accommodations", async (c) => {
  const destinationId = Number(c.req.param("destinationId"));
  const body = await c.req.json();
  const newAccommodation = await db
    .insert(accommodations)
    .values({ ...body, destinationId })
    .returning();
  return c.json(newAccommodation[0], 201);
});

// Direct /api/accommodations/:id
app.get("/accommodations/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const result = await db
    .select()
    .from(accommodations)
    .where(eq(accommodations.id, id));
  if (result.length === 0) {
    return c.json({ error: "Accommodation not found" }, 404);
  }
  return c.json(result[0]);
});

app.put("/accommodations/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json();
  const updated = await db
    .update(accommodations)
    .set(body)
    .where(eq(accommodations.id, id))
    .returning();
  if (updated.length === 0) {
    return c.json({ error: "Accommodation not found" }, 404);
  }
  return c.json(updated[0]);
});

app.delete("/accommodations/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db
    .delete(accommodations)
    .where(eq(accommodations.id, id))
    .returning();
  if (deleted.length === 0) {
    return c.json({ error: "Accommodation not found" }, 404);
  }
  return c.json({ message: "Accommodation deleted" });
});

export default app;

