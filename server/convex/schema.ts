import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Users table - stores Clerk user information
  users: defineTable({
    clerkId: v.string(),
    email: v.optional(v.string()),
    name: v.optional(v.string()),
    imageUrl: v.optional(v.string()),
  }).index("by_clerk_id", ["clerkId"]),

  trips: defineTable({
    userId: v.id("users"),
    name: v.string(),
    startDate: v.string(),
    endDate: v.string(),
    notes: v.optional(v.string()),
  }).index("by_user", ["userId"]),

  accommodations: defineTable({
    tripId: v.id("trips"),
    hotelName: v.string(),
    roomType: v.optional(v.string()),
    checkIn: v.optional(v.string()),
    checkInTime: v.optional(v.string()),
    checkOut: v.optional(v.string()),
    checkOutTime: v.optional(v.string()),
    address: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
  })
    .index("by_trip", ["tripId"])
    .index("by_trip_and_checkin", ["tripId", "checkIn"]),

  flights: defineTable({
    tripId: v.id("trips"),
    flightNumber: v.string(),
    airline: v.string(),
    departureAirportCode: v.string(),
    arrivalAirportCode: v.string(),
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
    aircraft: v.optional(v.string()),
    confirmationNumber: v.optional(v.string()),
    eTicketNumber: v.optional(v.string()),
    notes: v.optional(v.string()),
    // Live status fields (from AeroAPI)
    departureGate: v.optional(v.string()),
    status: v.optional(v.string()), // "Scheduled" | "En Route" | "Landed" | "Cancelled"
    statusLastUpdated: v.optional(v.number()),
  })
    .index("by_trip", ["tripId"])
    .index("by_trip_and_date", ["tripId", "departureDate"]),

  activities: defineTable({
    tripId: v.id("trips"),
    date: v.string(),
    time: v.optional(v.string()),
    title: v.string(),
    location: v.optional(v.string()),
    type: v.optional(v.string()),
    notes: v.optional(v.string()),
  })
    .index("by_trip", ["tripId"])
    .index("by_trip_and_date", ["tripId", "date"]),

  checklistSections: defineTable({
    tripId: v.id("trips"),
    name: v.string(),
    order: v.number(),
  }).index("by_trip", ["tripId"]),

  checklistItems: defineTable({
    sectionId: v.id("checklistSections"),
    text: v.string(),
    completed: v.boolean(),
    order: v.number(),
  }).index("by_section", ["sectionId"]),
});
