import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";

export const trips = pgTable("trips", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  destination: text("destination").notNull(),
  startDate: text("start_date"),
  endDate: text("end_date"),
  notes: text("notes"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow(),
});
