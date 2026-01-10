"use node";

import { ActionCache } from "@convex-dev/action-cache";
import { v } from "convex/values";
import { action, internalAction } from "./_generated/server";
import { components, internal } from "./_generated/api";

// Flight status data from AeroAPI
interface FlightStatusData {
  status: string | null;
  departureGate: string | null;
}

// Cache for flight status (15 min TTL)
const flightStatusCache = new ActionCache(components.actionCache, {
  action: internal.flightStatus.fetchFlightStatusInternal,
  name: "flight-status-v1",
  ttl: 1000 * 60 * 15, // 15 minutes
});

// Internal action to fetch flight status from AeroAPI
export const fetchFlightStatusInternal = internalAction({
  args: {
    flightIdent: v.string(), // e.g., "AA123"
    departureDate: v.string(), // YYYY-MM-DD
  },
  handler: async (_, args): Promise<FlightStatusData | null> => {
    const apiKey = process.env.AERO_API_KEY;
    if (!apiKey) {
      console.error("AERO_API_KEY not configured");
      return null;
    }

    const { flightIdent, departureDate } = args;

    try {
      const url = new URL(
        `https://aeroapi.flightaware.com/aeroapi/flights/${encodeURIComponent(flightIdent)}`
      );
      // Tell AeroAPI this is a flight designator, not a registration
      url.searchParams.set("ident_type", "designator");
      // Date range filter - use the departure date
      url.searchParams.set("start", `${departureDate}T00:00:00Z`);
      url.searchParams.set("end", `${departureDate}T23:59:59Z`);

      const response = await fetch(url.toString(), {
        headers: {
          "x-apikey": apiKey,
        },
      });

      if (!response.ok) {
        console.error(`AeroAPI error: ${response.status} ${response.statusText}`);
        const errorText = await response.text();
        console.error("AeroAPI error body:", errorText);
        return null;
      }

      const data = await response.json();
      const flights = data.flights as Array<{
        status: string;
        gate_origin: string | null;
        gate_destination: string | null;
        scheduled_out: string | null;
        scheduled_in: string | null;
      }>;

      if (!flights || flights.length === 0) {
        return null;
      }

      // Take the first matching flight
      const flight = flights[0];

      return {
        status: flight.status ?? null,
        departureGate: flight.gate_origin ?? null,
      };
    } catch (e) {
      console.error("Error fetching flight status:", e);
      return null;
    }
  },
});

// Public action to refresh flight status
export const refreshFlightStatus = action({
  args: {
    flightId: v.id("flights"),
  },
  handler: async (ctx, args): Promise<FlightStatusData | null> => {
    // Get the flight details first (query is in flights.ts, not here, since this file uses Node.js)
    const flight = await ctx.runQuery(internal.flights.getFlightForStatus, {
      flightId: args.flightId,
    });

    if (!flight) {
      console.error("Flight not found:", args.flightId);
      return null;
    }

    // Build flight identifier (e.g., "SQ37")
    // AeroAPI expects IATA/ICAO code + number, e.g., "SQ37" or "UAL123"
    // flightNumber field typically already contains this (e.g., "SQ37")
    const flightIdent = flight.flightNumber.replace(/\s+/g, "");

    // Fetch status from cache (or API if cache miss)
    const statusData = await flightStatusCache.fetch(ctx, {
      flightIdent,
      departureDate: flight.departureDate,
    });

    if (statusData) {
      // Update the flight record in DB
      await ctx.runMutation(internal.flights.updateFlightStatus, {
        flightId: args.flightId,
        status: statusData.status ?? undefined,
        departureGate: statusData.departureGate ?? undefined,
        statusLastUpdated: Date.now(),
      });
    }

    return statusData;
  },
});
