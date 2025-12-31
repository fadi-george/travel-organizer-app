import { Hono } from "hono";
import { db } from "../db";
import { trips } from "../db/schema";
import { eq } from "drizzle-orm";

const app = new Hono();

app.get("/", async (c) => {
  const allTrips = await db.query.trips.findMany({
    with: {
      destinations: {
        with: {
          accommodations: true,
        },
      },
      flights: true,
      activities: true,
    },
  });
  return c.json(allTrips);
});

app.post("/", async (c) => {
  const body = await c.req.json();
  const newTrip = await db.insert(trips).values(body).returning();
  return c.json(newTrip[0], 201);
});

app.get("/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const trip = await db.query.trips.findFirst({
    where: eq(trips.id, id),
    with: {
      destinations: {
        with: {
          accommodations: true,
        },
      },
      flights: true,
      activities: true,
    },
  });
  if (!trip) {
    return c.json({ error: "Trip not found" }, 404);
  }
  return c.json(trip);
});

app.put("/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const body = await c.req.json();
  const updated = await db
    .update(trips)
    .set({ ...body, updatedAt: new Date() })
    .where(eq(trips.id, id))
    .returning();
  if (updated.length === 0) {
    return c.json({ error: "Trip not found" }, 404);
  }
  return c.json(updated[0]);
});

app.delete("/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db.delete(trips).where(eq(trips.id, id)).returning();
  if (deleted.length === 0) {
    return c.json({ error: "Trip not found" }, 404);
  }
  return c.json({ message: "Trip deleted" });
});

export default app;

