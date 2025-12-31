import { db } from "./db";
import { trips } from "./db/schema";
import { eq } from "drizzle-orm";

Bun.serve({
  port: process.env.PORT ?? 3000,
  routes: {
    "/api/trips": {
      GET: async () => {
        const allTrips = await db.select().from(trips);
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
        const trip = await db.select().from(trips).where(eq(trips.id, id));
        if (trip.length === 0) {
          return Response.json({ error: "Trip not found" }, { status: 404 });
        }
        return Response.json(trip[0]);
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
  },
  fetch(req) {
    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Server running on http://localhost:${process.env.PORT ?? 3000}`);

