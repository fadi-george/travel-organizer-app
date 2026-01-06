"use node";

import { ActionCache } from "@convex-dev/action-cache";
import { v } from "convex/values";
import { action, internalAction } from "./_generated/server";
import { components, internal } from "./_generated/api";

// Weather condition mapping (matches Flutter's WeatherCondition enum)
type WeatherCondition =
  | "clear"
  | "fewClouds"
  | "cloudy"
  | "mist"
  | "drizzle"
  | "rain"
  | "thunderstorm"
  | "snow"
  | "unknown";

// Map OpenWeatherMap icon codes to weather conditions
function mapIconToCondition(iconCode: string): WeatherCondition {
  if (iconCode.startsWith("01")) return "clear";
  if (iconCode.startsWith("02")) return "fewClouds";
  if (iconCode.startsWith("03") || iconCode.startsWith("04")) return "cloudy";
  if (iconCode.startsWith("09")) return "drizzle";
  if (iconCode.startsWith("10")) return "rain";
  if (iconCode.startsWith("11")) return "thunderstorm";
  if (iconCode.startsWith("13")) return "snow";
  if (iconCode.startsWith("50")) return "mist";
  return "unknown";
}

// Hourly weather data structure
interface HourlyWeatherData {
  time: number; // Unix timestamp in milliseconds
  temperature: number; // Fahrenheit
  condition: string;
  weatherCondition: WeatherCondition;
  precipitationChance: number; // 0-100
  tempHigh?: number;
  tempLow?: number;
}

// Round coordinates to 2 decimal places for cache key (about 1km precision)
function roundCoord(coord: number): number {
  return Math.round(coord * 100) / 100;
}

// Build a cache key from lat/lng/date
function buildCacheKey(lat: number, lng: number, date: string): string {
  return `${roundCoord(lat)}_${roundCoord(lng)}_${date}`;
}

// Cache for today/tomorrow weather (1 hour TTL)
const hourlyWeatherCache = new ActionCache(components.actionCache, {
  action: internal.weather.fetchHourlyWeatherInternal,
  name: "hourly-weather-v1",
  ttl: 1000 * 60 * 60, // 1 hour
});

// Cache for 3+ days forecast (2 hour TTL)
const dailyWeatherCache = new ActionCache(components.actionCache, {
  action: internal.weather.fetchDailyWeatherInternal,
  name: "daily-weather-v1",
  ttl: 1000 * 60 * 60 * 2, // 2 hours
});

// Internal action to fetch hourly weather from OpenWeatherMap
export const fetchHourlyWeatherInternal = internalAction({
  args: {
    lat: v.number(),
    lng: v.number(),
    date: v.string(),
  },
  handler: async (_, args): Promise<HourlyWeatherData[] | null> => {
    const apiKey = process.env.OPENWEATHERMAP_API_KEY;
    if (!apiKey) {
      console.error("OPENWEATHERMAP_API_KEY not configured");
      return null;
    }

    const { lat, lng, date } = args;
    const requestedDate = new Date(date);
    const targetDate = new Date(
      requestedDate.getFullYear(),
      requestedDate.getMonth(),
      requestedDate.getDate()
    );
    const nextDay = new Date(targetDate.getTime() + 24 * 60 * 60 * 1000);

    // Target hours: 8am through midnight
    const targetHours = [8, 10, 12, 14, 16, 18, 20, 22, 0];

    try {
      // Use One Call API 3.0 for hourly forecast
      const url = new URL("https://api.openweathermap.org/data/3.0/onecall");
      url.searchParams.set("lat", lat.toString());
      url.searchParams.set("lon", lng.toString());
      url.searchParams.set("exclude", "minutely,daily,alerts");
      url.searchParams.set("units", "imperial");
      url.searchParams.set("appid", apiKey);

      const response = await fetch(url.toString());
      if (!response.ok) {
        console.error(`OpenWeatherMap API error: ${response.status}`);
        return null;
      }

      const data = await response.json();
      const hourlyData = data.hourly as Array<{
        dt: number;
        temp: number;
        pop?: number;
        weather: Array<{ main: string; icon: string }>;
      }>;

      if (!hourlyData) return null;

      // Parse and filter to target hours
      const results: HourlyWeatherData[] = [];

      for (const hour of targetHours) {
        const targetTime =
          hour === 0
            ? new Date(nextDay.getFullYear(), nextDay.getMonth(), nextDay.getDate(), 0)
            : new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), hour);

        // Find closest hour in forecast data
        let closest: HourlyWeatherData | null = null;
        let minDiff = 999999;

        for (const hourData of hourlyData) {
          const weatherTime = new Date(hourData.dt * 1000);
          const diff = Math.abs(weatherTime.getTime() - targetTime.getTime()) / (1000 * 60);

          if (diff < minDiff) {
            minDiff = diff;
            const iconCode = hourData.weather[0]?.icon ?? "01d";
            closest = {
              time: hourData.dt * 1000,
              temperature: hourData.temp,
              condition: hourData.weather[0]?.main ?? "Unknown",
              weatherCondition: mapIconToCondition(iconCode),
              precipitationChance: Math.round((hourData.pop ?? 0) * 100),
            };
          }
        }

        if (closest && minDiff <= 90) {
          results.push(closest);
        }
      }

      return results;
    } catch (e) {
      console.error("Error fetching hourly weather:", e);
      return null;
    }
  },
});

// Internal action to fetch daily weather from OpenWeatherMap
export const fetchDailyWeatherInternal = internalAction({
  args: {
    lat: v.number(),
    lng: v.number(),
    date: v.string(),
  },
  handler: async (_, args): Promise<HourlyWeatherData[] | null> => {
    const apiKey = process.env.OPENWEATHERMAP_API_KEY;
    if (!apiKey) {
      console.error("OPENWEATHERMAP_API_KEY not configured");
      return null;
    }

    const { lat, lng, date } = args;
    const requestedDate = new Date(date);
    const targetDate = new Date(
      requestedDate.getFullYear(),
      requestedDate.getMonth(),
      requestedDate.getDate()
    );

    try {
      // Use One Call API 3.0 for daily forecast
      const url = new URL("https://api.openweathermap.org/data/3.0/onecall");
      url.searchParams.set("lat", lat.toString());
      url.searchParams.set("lon", lng.toString());
      url.searchParams.set("exclude", "minutely,hourly,alerts,current");
      url.searchParams.set("units", "imperial");
      url.searchParams.set("appid", apiKey);

      const response = await fetch(url.toString());
      if (!response.ok) {
        console.error(`OpenWeatherMap API error: ${response.status}`);
        return null;
      }

      const data = await response.json();
      const dailyData = data.daily as Array<{
        dt: number;
        temp: { min: number; max: number };
        pop?: number;
        weather: Array<{ main: string; icon: string }>;
      }>;

      if (!dailyData || dailyData.length === 0) return null;

      // Find matching day
      for (const day of dailyData) {
        const dayTime = new Date(day.dt * 1000);
        const dayDate = new Date(dayTime.getFullYear(), dayTime.getMonth(), dayTime.getDate());

        if (dayDate.getTime() === targetDate.getTime()) {
          const iconCode = day.weather[0]?.icon ?? "01d";

          // Return as single entry at noon with high/low temps
          return [
            {
              time: new Date(
                targetDate.getFullYear(),
                targetDate.getMonth(),
                targetDate.getDate(),
                12
              ).getTime(),
              temperature: day.temp.max,
              condition: day.weather[0]?.main ?? "Unknown",
              weatherCondition: mapIconToCondition(iconCode),
              precipitationChance: Math.round((day.pop ?? 0) * 100),
              tempHigh: day.temp.max,
              tempLow: day.temp.min,
            },
          ];
        }
      }

      console.log("Date not found in forecast range");
      return null;
    } catch (e) {
      console.error("Error fetching daily weather:", e);
      return null;
    }
  },
});

// Public action exposed to Flutter client
export const getWeather = action({
  args: {
    lat: v.number(),
    lng: v.number(),
    date: v.string(), // ISO date string (YYYY-MM-DD)
  },
  handler: async (ctx, args): Promise<HourlyWeatherData[] | null> => {
    const { lat, lng, date } = args;

    // Calculate days ahead
    const requestedDate = new Date(date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    requestedDate.setHours(0, 0, 0, 0);

    const daysAhead = Math.floor(
      (requestedDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24)
    );

    // Past dates - not supported for caching (would need Time Machine API)
    if (daysAhead < 0) {
      console.log("Historical weather not supported via server cache");
      return null;
    }

    // Beyond forecast range
    if (daysAhead > 8) {
      console.log("Date is outside forecast range (max 8 days)");
      return null;
    }

    // Round coordinates for cache key consistency
    const roundedLat = roundCoord(lat);
    const roundedLng = roundCoord(lng);

    // Use appropriate cache based on days ahead
    if (daysAhead <= 2) {
      // Today/tomorrow - use hourly cache (1 hour TTL)
      return await hourlyWeatherCache.fetch(ctx, {
        lat: roundedLat,
        lng: roundedLng,
        date,
      });
    } else {
      // 3+ days - use daily cache (2 hour TTL)
      return await dailyWeatherCache.fetch(ctx, {
        lat: roundedLat,
        lng: roundedLng,
        date,
      });
    }
  },
});

