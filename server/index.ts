import { db } from "./db";
import {
  trips,
  destinations,
  accommodations,
  flights,
  activities,
} from "./db/schema";
import { eq } from "drizzle-orm";

Bun.serve({
  port: process.env.PORT ?? 3000,
  routes: {
    // ============ TRIPS ============
    "/api/trips": {
      GET: async () => {
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
        return Response.json(allTrips);
      },
      POST: async (req) => {
        const body = await req.json();
        const newTrip = await db.insert(trips).values(body).returning();
        return Response.json(newTrip[0], { status: 201 });
      },
    },
    "/api/trips/:id": {
      GET: async (req) => {
        const id = Number(req.params.id);
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
          return Response.json({ error: "Trip not found" }, { status: 404 });
        }
        return Response.json(trip);
      },
      PUT: async (req) => {
        const id = Number(req.params.id);
        const body = await req.json();
        const updated = await db
          .update(trips)
          .set({ ...body, updatedAt: new Date() })
          .where(eq(trips.id, id))
          .returning();
        if (updated.length === 0) {
          return Response.json({ error: "Trip not found" }, { status: 404 });
        }
        return Response.json(updated[0]);
      },
      DELETE: async (req) => {
        const id = Number(req.params.id);
        const deleted = await db
          .delete(trips)
          .where(eq(trips.id, id))
          .returning();
        if (deleted.length === 0) {
          return Response.json({ error: "Trip not found" }, { status: 404 });
        }
        return Response.json({ message: "Trip deleted" });
      },
    },

    // ============ DESTINATIONS ============
    "/api/trips/:tripId/destinations": {
      GET: async (req) => {
        const tripId = Number(req.params.tripId);
        const result = await db
          .select()
          .from(destinations)
          .where(eq(destinations.tripId, tripId));
        return Response.json(result);
      },
      POST: async (req) => {
        const tripId = Number(req.params.tripId);
        const body = await req.json();
        const newDestination = await db
          .insert(destinations)
          .values({ ...body, tripId })
          .returning();
        return Response.json(newDestination[0], { status: 201 });
      },
    },
    "/api/destinations/:id": {
      GET: async (req) => {
        const id = Number(req.params.id);
        const destination = await db.query.destinations.findFirst({
          where: eq(destinations.id, id),
          with: {
            accommodations: true,
          },
        });
        if (!destination) {
          return Response.json(
            { error: "Destination not found" },
            { status: 404 }
          );
        }
        return Response.json(destination);
      },
      PUT: async (req) => {
        const id = Number(req.params.id);
        const body = await req.json();
        const updated = await db
          .update(destinations)
          .set(body)
          .where(eq(destinations.id, id))
          .returning();
        if (updated.length === 0) {
          return Response.json(
            { error: "Destination not found" },
            { status: 404 }
          );
        }
        return Response.json(updated[0]);
      },
      DELETE: async (req) => {
        const id = Number(req.params.id);
        const deleted = await db
          .delete(destinations)
          .where(eq(destinations.id, id))
          .returning();
        if (deleted.length === 0) {
          return Response.json(
            { error: "Destination not found" },
            { status: 404 }
          );
        }
        return Response.json({ message: "Destination deleted" });
      },
    },

    // ============ ACCOMMODATIONS ============
    "/api/destinations/:destinationId/accommodations": {
      GET: async (req) => {
        const destinationId = Number(req.params.destinationId);
        const result = await db
          .select()
          .from(accommodations)
          .where(eq(accommodations.destinationId, destinationId));
        return Response.json(result);
      },
      POST: async (req) => {
        const destinationId = Number(req.params.destinationId);
        const body = await req.json();
        const newAccommodation = await db
          .insert(accommodations)
          .values({ ...body, destinationId })
          .returning();
        return Response.json(newAccommodation[0], { status: 201 });
      },
    },
    "/api/accommodations/:id": {
      GET: async (req) => {
        const id = Number(req.params.id);
        const result = await db
          .select()
          .from(accommodations)
          .where(eq(accommodations.id, id));
        if (result.length === 0) {
          return Response.json(
            { error: "Accommodation not found" },
            { status: 404 }
          );
        }
        return Response.json(result[0]);
      },
      PUT: async (req) => {
        const id = Number(req.params.id);
        const body = await req.json();
        const updated = await db
          .update(accommodations)
          .set(body)
          .where(eq(accommodations.id, id))
          .returning();
        if (updated.length === 0) {
          return Response.json(
            { error: "Accommodation not found" },
            { status: 404 }
          );
        }
        return Response.json(updated[0]);
      },
      DELETE: async (req) => {
        const id = Number(req.params.id);
        const deleted = await db
          .delete(accommodations)
          .where(eq(accommodations.id, id))
          .returning();
        if (deleted.length === 0) {
          return Response.json(
            { error: "Accommodation not found" },
            { status: 404 }
          );
        }
        return Response.json({ message: "Accommodation deleted" });
      },
    },

    // ============ FLIGHTS ============
    "/api/trips/:tripId/flights": {
      GET: async (req) => {
        const tripId = Number(req.params.tripId);
        const result = await db
          .select()
          .from(flights)
          .where(eq(flights.tripId, tripId));
        return Response.json(result);
      },
      POST: async (req) => {
        const tripId = Number(req.params.tripId);
        const body = await req.json();
        const newFlight = await db
          .insert(flights)
          .values({ ...body, tripId })
          .returning();
        return Response.json(newFlight[0], { status: 201 });
      },
    },
    "/api/flights/:id": {
      GET: async (req) => {
        const id = Number(req.params.id);
        const result = await db
          .select()
          .from(flights)
          .where(eq(flights.id, id));
        if (result.length === 0) {
          return Response.json({ error: "Flight not found" }, { status: 404 });
        }
        return Response.json(result[0]);
      },
      PUT: async (req) => {
        const id = Number(req.params.id);
        const body = await req.json();
        const updated = await db
          .update(flights)
          .set(body)
          .where(eq(flights.id, id))
          .returning();
        if (updated.length === 0) {
          return Response.json({ error: "Flight not found" }, { status: 404 });
        }
        return Response.json(updated[0]);
      },
      DELETE: async (req) => {
        const id = Number(req.params.id);
        const deleted = await db
          .delete(flights)
          .where(eq(flights.id, id))
          .returning();
        if (deleted.length === 0) {
          return Response.json({ error: "Flight not found" }, { status: 404 });
        }
        return Response.json({ message: "Flight deleted" });
      },
    },

    // ============ ACTIVITIES ============
    "/api/trips/:tripId/activities": {
      GET: async (req) => {
        const tripId = Number(req.params.tripId);
        const result = await db
          .select()
          .from(activities)
          .where(eq(activities.tripId, tripId));
        return Response.json(result);
      },
      POST: async (req) => {
        const tripId = Number(req.params.tripId);
        const body = await req.json();
        const newActivity = await db
          .insert(activities)
          .values({ ...body, tripId })
          .returning();
        return Response.json(newActivity[0], { status: 201 });
      },
    },
    "/api/activities/:id": {
      GET: async (req) => {
        const id = Number(req.params.id);
        const result = await db
          .select()
          .from(activities)
          .where(eq(activities.id, id));
        if (result.length === 0) {
          return Response.json(
            { error: "Activity not found" },
            { status: 404 }
          );
        }
        return Response.json(result[0]);
      },
      PUT: async (req) => {
        const id = Number(req.params.id);
        const body = await req.json();
        const updated = await db
          .update(activities)
          .set(body)
          .where(eq(activities.id, id))
          .returning();
        if (updated.length === 0) {
          return Response.json(
            { error: "Activity not found" },
            { status: 404 }
          );
        }
        return Response.json(updated[0]);
      },
      DELETE: async (req) => {
        const id = Number(req.params.id);
        const deleted = await db
          .delete(activities)
          .where(eq(activities.id, id))
          .returning();
        if (deleted.length === 0) {
          return Response.json(
            { error: "Activity not found" },
            { status: 404 }
          );
        }
        return Response.json({ message: "Activity deleted" });
      },
    },
  },
  fetch(req) {
    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Server running on http://localhost:${process.env.PORT ?? 3000}`);
