CREATE TABLE "accommodations" (
	"id" serial PRIMARY KEY NOT NULL,
	"destination_id" integer NOT NULL,
	"hotel_name" text NOT NULL,
	"city" text,
	"room_type" text,
	"check_in" text,
	"check_out" text,
	"address" text,
	"confirmation_number" text,
	"notes" text
);
--> statement-breakpoint
CREATE TABLE "activities" (
	"id" serial PRIMARY KEY NOT NULL,
	"trip_id" integer NOT NULL,
	"date" text NOT NULL,
	"time" text,
	"title" text NOT NULL,
	"description" text,
	"location" text,
	"type" text,
	"notes" text
);
--> statement-breakpoint
CREATE TABLE "destinations" (
	"id" serial PRIMARY KEY NOT NULL,
	"trip_id" integer NOT NULL,
	"country" text NOT NULL,
	"arrival_date" text,
	"departure_date" text,
	"notes" text
);
--> statement-breakpoint
CREATE TABLE "flights" (
	"id" serial PRIMARY KEY NOT NULL,
	"trip_id" integer NOT NULL,
	"flight_number" text NOT NULL,
	"airline" text NOT NULL,
	"departure_city" text NOT NULL,
	"arrival_city" text NOT NULL,
	"departure_date" text NOT NULL,
	"departure_time" text,
	"arrival_date" text,
	"arrival_time" text,
	"departure_terminal" text,
	"arrival_terminal" text,
	"duration" text,
	"cabin_class" text,
	"seat_number" text,
	"baggage_allowance" text,
	"status" text,
	"aircraft" text,
	"confirmation_number" text,
	"e_ticket_number" text,
	"notes" text
);
--> statement-breakpoint
CREATE TABLE "trips" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"start_date" text,
	"end_date" text,
	"notes" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "accommodations" ADD CONSTRAINT "accommodations_destination_id_destinations_id_fk" FOREIGN KEY ("destination_id") REFERENCES "public"."destinations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activities" ADD CONSTRAINT "activities_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "destinations" ADD CONSTRAINT "destinations_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "flights" ADD CONSTRAINT "flights_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;