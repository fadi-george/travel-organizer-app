# Travel Organizer App

A travel itinerary organizer API built with Bun, Drizzle ORM, and PostgreSQL (Supabase).

## Features

- Manage trips with multiple destinations
- Track accommodations per destination
- Store flight details with full booking info
- Organize daily activities and itinerary

## Setup

### Prerequisites

- [Bun](https://bun.sh) installed
- [Supabase](https://supabase.com) account (free tier works)

### Installation

1. Clone the repo:

   ```bash
   git clone <repo-url>
   cd travel-organizer-app
   ```

2. Install dependencies:

   ```bash
   bun install
   ```

3. Create a Supabase project and get your connection string:

   - Go to [Supabase Dashboard](https://supabase.com/dashboard)
   - Create a new project
   - Go to **Project Settings > Database > Connection string > URI**

4. Set up environment variables:

   ```bash
   cp .env.example .env
   # Edit .env with your Supabase connection string
   ```

5. Run database migrations:

   ```bash
   bun run db:migrate
   ```

6. Start the development server:
   ```bash
   bun run dev
   ```

The API will be running at `http://localhost:3000`

## API Endpoints

### Trips

- `GET /api/trips` - List all trips
- `POST /api/trips` - Create a trip
- `GET /api/trips/:id` - Get trip with all related data
- `PUT /api/trips/:id` - Update a trip
- `DELETE /api/trips/:id` - Delete a trip

### Destinations

- `GET /api/trips/:tripId/destinations` - List destinations for a trip
- `POST /api/trips/:tripId/destinations` - Add a destination
- `GET /api/destinations/:id` - Get destination with accommodations
- `PUT /api/destinations/:id` - Update a destination
- `DELETE /api/destinations/:id` - Delete a destination

### Accommodations

- `GET /api/destinations/:destinationId/accommodations` - List accommodations
- `POST /api/destinations/:destinationId/accommodations` - Add accommodation
- `GET /api/accommodations/:id` - Get accommodation
- `PUT /api/accommodations/:id` - Update accommodation
- `DELETE /api/accommodations/:id` - Delete accommodation

### Flights

- `GET /api/trips/:tripId/flights` - List flights for a trip
- `POST /api/trips/:tripId/flights` - Add a flight
- `GET /api/flights/:id` - Get flight
- `PUT /api/flights/:id` - Update flight
- `DELETE /api/flights/:id` - Delete flight

### Activities

- `GET /api/trips/:tripId/activities` - List activities for a trip
- `POST /api/trips/:tripId/activities` - Add an activity
- `GET /api/activities/:id` - Get activity
- `PUT /api/activities/:id` - Update activity
- `DELETE /api/activities/:id` - Delete activity

## Scripts

| Script                | Description                      |
| --------------------- | -------------------------------- |
| `bun run dev`         | Start dev server with hot reload |
| `bun run db:generate` | Generate migration files         |
| `bun run db:migrate`  | Apply migrations to database     |
| `bun run db:studio`   | Open Drizzle Studio              |

## Troubleshooting

If `db:migrate` fails with a CHECK constraint error, run the SQL directly in Supabase:

1. Go to Supabase Dashboard > SQL Editor
2. Copy contents of `drizzle/0000_misty_dark_beast.sql`
3. Run the SQL manually
