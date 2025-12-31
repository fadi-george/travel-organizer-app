import { relations } from "drizzle-orm";
import { pgTable, serial, text, timestamp, integer } from "drizzle-orm/pg-core";

// ============ TABLES ============

export const trips = pgTable("trips", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  startDate: text("start_date"),
  endDate: text("end_date"),
  notes: text("notes"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
});

export const destinations = pgTable("destinations", {
  id: serial("id").primaryKey(),
  tripId: integer("trip_id")
    .notNull()
    .references(() => trips.id, { onDelete: "cascade" }),
  country: text("country").notNull(),
  arrivalDate: text("arrival_date"),
  departureDate: text("departure_date"),
  notes: text("notes"),
});

export const accommodations = pgTable("accommodations", {
  id: serial("id").primaryKey(),
  destinationId: integer("destination_id")
    .notNull()
    .references(() => destinations.id, { onDelete: "cascade" }),
  hotelName: text("hotel_name").notNull(),
  city: text("city"),
  roomType: text("room_type"),
  checkIn: text("check_in"),
  checkOut: text("check_out"),
  address: text("address"),
  confirmationNumber: text("confirmation_number"),
  notes: text("notes"),
});

export const flights = pgTable("flights", {
  id: serial("id").primaryKey(),
  tripId: integer("trip_id")
    .notNull()
    .references(() => trips.id, { onDelete: "cascade" }),
  flightNumber: text("flight_number").notNull(),
  airline: text("airline").notNull(),
  departureCity: text("departure_city").notNull(),
  arrivalCity: text("arrival_city").notNull(),
  departureDate: text("departure_date").notNull(),
  departureTime: text("departure_time"),
  arrivalDate: text("arrival_date"),
  arrivalTime: text("arrival_time"),
  departureTerminal: text("departure_terminal"),
  arrivalTerminal: text("arrival_terminal"),
  duration: text("duration"),
  cabinClass: text("cabin_class"),
  seatNumber: text("seat_number"),
  baggageAllowance: text("baggage_allowance"),
  status: text("status"),
  aircraft: text("aircraft"),
  confirmationNumber: text("confirmation_number"),
  eTicketNumber: text("e_ticket_number"),
  notes: text("notes"),
});

export const activities = pgTable("activities", {
  id: serial("id").primaryKey(),
  tripId: integer("trip_id")
    .notNull()
    .references(() => trips.id, { onDelete: "cascade" }),
  date: text("date").notNull(),
  time: text("time"),
  title: text("title").notNull(),
  description: text("description"),
  location: text("location"),
  type: text("type"),
  notes: text("notes"),
});

// ============ RELATIONS ============

export const tripsRelations = relations(trips, ({ many }) => ({
  destinations: many(destinations),
  flights: many(flights),
  activities: many(activities),
}));

export const destinationsRelations = relations(destinations, ({ one, many }) => ({
  trip: one(trips, {
    fields: [destinations.tripId],
    references: [trips.id],
  }),
  accommodations: many(accommodations),
}));

export const accommodationsRelations = relations(accommodations, ({ one }) => ({
  destination: one(destinations, {
    fields: [accommodations.destinationId],
    references: [destinations.id],
  }),
}));

export const flightsRelations = relations(flights, ({ one }) => ({
  trip: one(trips, {
    fields: [flights.tripId],
    references: [trips.id],
  }),
}));

export const activitiesRelations = relations(activities, ({ one }) => ({
  trip: one(trips, {
    fields: [activities.tripId],
    references: [trips.id],
  }),
}));
