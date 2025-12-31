# Travel Organizer App

A travel itinerary organizer with a Flutter client and Convex backend.

## Features

- Manage trips with multiple destinations
- Track accommodations per destination
- Store flight details with full booking info
- Organize daily activities and itinerary

## Setup

### Prerequisites

- [Bun](https://bun.sh) installed
- [Flutter](https://flutter.dev) installed (for mobile client)

### Installation

1. Install dependencies:

   ```bash
   bun install
   ```

2. Start Convex development server:

   ```bash
   bun run dev:convex
   ```

   This will prompt you to:
   - Log in with GitHub
   - Create a new Convex project
   - Sync your functions to the cloud

3. Your backend is ready! Convex provides real-time subscriptions out of the box.

## Convex Functions

| Module           | Functions                                                |
| ---------------- | -------------------------------------------------------- |
| `trips`          | `list`, `get`, `create`, `update`, `remove`              |
| `destinations`   | `listByTrip`, `get`, `create`, `update`, `remove`        |
| `accommodations` | `listByDestination`, `get`, `create`, `update`, `remove` |
| `flights`        | `listByTrip`, `get`, `create`, `update`, `remove`        |
| `activities`     | `listByTrip`, `get`, `create`, `update`, `remove`        |

## Scripts

| Script               | Description             |
| -------------------- | ----------------------- |
| `bun run dev:convex` | Start Convex dev server |
| `bun run dev:client` | Run Flutter client      |

## Project Structure

```
travel-organizer-app/
├── client/                 # Flutter mobile app
├── server/
│   └── convex/            # Convex backend functions
│       ├── schema.ts      # Database schema
│       ├── trips.ts       # Trip functions
│       ├── destinations.ts
│       ├── accommodations.ts
│       ├── flights.ts
│       └── activities.ts
├── convex.json            # Convex configuration
└── package.json
```

## Troubleshooting

If functions fail to sync, ensure you're logged in:

```bash
bunx convex login
```
