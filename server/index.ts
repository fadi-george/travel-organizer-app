import { Hono } from "hono";
import { db } from "./db";
import {
  trips,
  destinations,
  accommodations,
  flights,
  activities,
} from "./db/schema";
import { eq } from "drizzle-orm";

const app = new Hono();

// ============ TRIPS ============

app.get("/api/trips", async (c) => {
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

app.post("/api/trips", async (c) => {
  const body = await c.req.json();
  const newTrip = await db.insert(trips).values(body).returning();
  return c.json(newTrip[0], 201);
});

app.get("/api/trips/:id", async (c) => {
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

app.put("/api/trips/:id", async (c) => {
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

app.delete("/api/trips/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const deleted = await db.delete(trips).where(eq(trips.id, id)).returning();
  if (deleted.length === 0) {
    return c.json({ error: "Trip not found" }, 404);
  }
  return c.json({ message: "Trip deleted" });
});

// ============ DESTINATIONS ============

app.get("/api/trips/:tripId/destinations", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const result = await db
    .select()
    .from(destinations)
    .where(eq(destinations.tripId, tripId));
  return c.json(result);
});

app.post("/api/trips/:tripId/destinations", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const body = await c.req.json();
  const newDestination = await db
    .insert(destinations)
    .values({ ...body, tripId })
    .returning();
  return c.json(newDestination[0], 201);
});

app.get("/api/destinations/:id", async (c) => {
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

app.put("/api/destinations/:id", async (c) => {
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

app.delete("/api/destinations/:id", async (c) => {
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

// ============ ACCOMMODATIONS ============

app.get("/api/destinations/:destinationId/accommodations", async (c) => {
  const destinationId = Number(c.req.param("destinationId"));
  const result = await db
    .select()
    .from(accommodations)
    .where(eq(accommodations.destinationId, destinationId));
  return c.json(result);
});

app.post("/api/destinations/:destinationId/accommodations", async (c) => {
  const destinationId = Number(c.req.param("destinationId"));
  const body = await c.req.json();
  const newAccommodation = await db
    .insert(accommodations)
    .values({ ...body, destinationId })
    .returning();
  return c.json(newAccommodation[0], 201);
});

app.get("/api/accommodations/:id", async (c) => {
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

app.put("/api/accommodations/:id", async (c) => {
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

app.delete("/api/accommodations/:id", async (c) => {
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

// ============ FLIGHTS ============

app.get("/api/trips/:tripId/flights", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const result = await db
    .select()
    .from(flights)
    .where(eq(flights.tripId, tripId));
  return c.json(result);
});

app.post("/api/trips/:tripId/flights", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const body = await c.req.json();
  const newFlight = await db
    .insert(flights)
    .values({ ...body, tripId })
    .returning();
  return c.json(newFlight[0], 201);
});

app.get("/api/flights/:id", async (c) => {
  const id = Number(c.req.param("id"));
  const result = await db.select().from(flights).where(eq(flights.id, id));
  if (result.length === 0) {
    return c.json({ error: "Flight not found" }, 404);
  }
  return c.json(result[0]);
});

app.put("/api/flights/:id", async (c) => {
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

app.delete("/api/flights/:id", async (c) => {
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

// ============ ACTIVITIES ============

app.get("/api/trips/:tripId/activities", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const result = await db
    .select()
    .from(activities)
    .where(eq(activities.tripId, tripId));
  return c.json(result);
});

app.post("/api/trips/:tripId/activities", async (c) => {
  const tripId = Number(c.req.param("tripId"));
  const body = await c.req.json();
  const newActivity = await db
    .insert(activities)
    .values({ ...body, tripId })
    .returning();
  return c.json(newActivity[0], 201);
});

app.get("/api/activities/:id", async (c) => {
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

app.put("/api/activities/:id", async (c) => {
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

app.delete("/api/activities/:id", async (c) => {
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

// ============ START SERVER ============

const port = Number(process.env.PORT) || 3000;

export default {
  port,
  fetch: app.fetch,
};

console.log(`Server running on http://localhost:${port}`);
