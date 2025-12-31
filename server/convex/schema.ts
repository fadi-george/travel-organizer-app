import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  trips: defineTable({
    name: v.string(),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    notes: v.optional(v.string()),
  }),

  destinations: defineTable({
    tripId: v.id("trips"),
    country: v.string(),
    arrivalDate: v.optional(v.string()),
    departureDate: v.optional(v.string()),
    notes: v.optional(v.string()),
  }).index("by_trip", ["tripId"]),

  accommodations: defineTable({
    destinationId: v.id("destinations"),
    hotelName: v.string(),
    city: v.optional(v.string()),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  }).index("by_destination", ["destinationId"]),

  flights: defineTable({
    tripId: v.id("trips"),
    flightNumber: v.string(),
    airline: v.string(),
    departureCity: v.string(),
    arrivalCity: v.string(),
    departureDate: v.string(),
    departureTime: v.optional(v.string()),
    arrivalDate: v.optional(v.string()),
    arrivalTime: v.optional(v.string()),
    departureTerminal: v.optional(v.string()),
    arrivalTerminal: v.optional(v.string()),
    duration: v.optional(v.string()),
    cabinClass: v.optional(v.string()),
    seatNumber: v.optional(v.string()),
    baggageAllowance: v.optional(v.string()),
    status: v.optional(v.string()),
    aircraft: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    eTicketNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  }).index("by_trip", ["tripId"]),

  activities: defineTable({
    tripId: v.id("trips"),
    date: v.string(),
    time: v.optional(v.string()),
    title: v.string(),
    description: v.optional(v.string()),
    location: v.optional(v.string()),
    type: v.optional(v.string()),
    notes: v.optional(v.string()),
  }).index("by_trip", ["tripId"]),
});

