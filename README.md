# Travel Organizer App (Work in Progress)

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
- [Rust](https://rustup.rs) installed (required by `convex_flutter` package)

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

### Flutter Client Setup

1. Set up shared environment files (symlinks client env to root):

   ```bash
   bun run setup:client
   ```

2. **Configure Google Maps API Key** (required for map features):

   ```bash
   # Copy the example config
   cp client/ios/Flutter/Secrets.xcconfig.example client/ios/Flutter/Secrets.xcconfig
   ```

   Then edit `client/ios/Flutter/Secrets.xcconfig` and add your API key:

   ```
   GOOGLE_MAPS_API_KEY=your-actual-api-key-here
   ```

   To get an API key:
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Create a new API key
   - Enable these APIs: **Maps SDK for iOS**, **Maps SDK for Android**, **Geocoding API**, **Places API**

3. Install Flutter dependencies:

   ```bash
   cd client
   flutter pub get
   ```

4. Run the app:

   ```bash
   flutter run
   ```

> **Note:** The client uses `convex_flutter` which requires Rust. Make sure your Rust toolchain is up to date: `rustup update stable`

## Convex Functions

| Module           | Functions                                                |
| ---------------- | -------------------------------------------------------- |
| `trips`          | `list`, `get`, `create`, `update`, `remove`              |
| `destinations`   | `listByTrip`, `get`, `create`, `update`, `remove`        |
| `accommodations` | `listByDestination`, `get`, `create`, `update`, `remove` |
| `flights`        | `listByTrip`, `get`, `create`, `update`, `remove`        |
| `activities`     | `listByTrip`, `get`, `create`, `update`, `remove`        |

## Scripts

| Script                 | Description                           |
| ---------------------- | ------------------------------------- |
| `bun run setup:client` | Set up client env symlinks (run once) |
| `bun run dev:convex`   | Start Convex dev server               |
| `bun run dev:client`   | Run Flutter client                    |

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

### Convex functions fail to sync

Ensure you're logged in:

```bash
bunx convex login
```

### Gray screen instead of Google Maps

This means the Google Maps API key is missing or invalid:

1. Check that `client/ios/Flutter/Secrets.xcconfig` exists and has a valid API key
2. Check that `client/android/local.properties` has `GOOGLE_MAPS_API_KEY` set
3. Ensure the API key has these APIs enabled in Google Cloud Console:
   - Maps SDK for iOS
   - Maps SDK for Android
   - Geocoding API
   - Places API
4. **Restart the app** (not hot reload) after changing native config files

### "API key not found" or map loads but shows errors

Check the Google Cloud Console to ensure:
- The API key is not restricted to wrong bundle IDs/package names
- Billing is enabled on the Google Cloud project
- The required APIs are enabled
