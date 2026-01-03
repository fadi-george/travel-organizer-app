# Authentication Setup Guide

This guide explains how to complete the Clerk authentication setup for the Travel Organizer app.

## Overview

The app is configured to use **Clerk** for authentication with:

- **Google OAuth** - Sign in with Google
- **Magic Links** - Passwordless email sign-in

## Setup Steps

### 1. Create a Clerk Application

1. Go to [clerk.com](https://clerk.com) and create an account
2. Create a new application
3. In the Clerk Dashboard, enable the following authentication methods:
   - **Social connections**: Google
   - **Email**: Magic Links (under "Email, Phone, Username")

### 2. Get Your Clerk Credentials

From the Clerk Dashboard:

1. Go to **API Keys** page
2. Copy your **Publishable Key** (starts with `pk_test_` or `pk_live_`)
3. Note your **Issuer URL** (format: `https://verb-noun-00.clerk.accounts.dev`)

### 3. Configure the Flutter Client

Add your Clerk publishable key to the client environment:

```bash
# client/.env (or client/.env.local for development)
CLERK_PUBLISHABLE_KEY=pk_test_your_key_here
```

### 4. Configure the Convex Backend

Update `server/convex/auth.config.ts` with your Clerk issuer URL:

```typescript
export default {
  providers: [
    {
      domain: "https://your-clerk-domain.clerk.accounts.dev",
      applicationID: "convex",
    },
  ],
};
```

Then in the Convex Dashboard:

1. Go to Settings > Authentication
2. Add your Clerk provider configuration

### 5. (Optional) Integrate clerk_flutter Package

When the `clerk_flutter` package is stable, you can integrate it:

1. Uncomment in `client/pubspec.yaml`:

   ```yaml
   clerk_flutter: ^0.0.13-beta
   ```

2. Update `client/lib/main.dart` to wrap with ClerkAuth:

   ```dart
   return ClerkAuth(
     publishableKey: publishableKey,
     child: _buildMaterialApp(const AuthWrapper()),
   );
   ```

3. Update the AuthWrapper to use ClerkAuthBuilder

## Files Modified for Auth

### Backend (Convex)

| File                              | Purpose                                   |
| --------------------------------- | ----------------------------------------- |
| `server/convex/auth.config.ts`    | Clerk JWT verification config             |
| `server/convex/schema.ts`         | Added `users` table and `userId` to trips |
| `server/convex/users.ts`          | User management functions                 |
| `server/convex/trips.ts`          | Auth checks and user filtering            |
| `server/convex/flights.ts`        | Auth checks for trip ownership            |
| `server/convex/accommodations.ts` | Auth checks for trip ownership            |
| `server/convex/activities.ts`     | Auth checks for trip ownership            |
| `server/convex/lib/auth.ts`       | Shared auth helper functions              |

### Flutter Client

| File                                    | Purpose                         |
| --------------------------------------- | ------------------------------- |
| `client/lib/services/auth_service.dart` | Auth state management           |
| `client/lib/screens/login_screen.dart`  | Login UI                        |
| `client/lib/main.dart`                  | Auth initialization and routing |
| `client/lib/screens/trips_screen.dart`  | Profile menu with sign-out      |

## How Auth Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │     │     Clerk       │     │    Convex       │
│                 │     │                 │     │                 │
│  1. Sign in     │────▶│  2. Validate    │     │                 │
│                 │     │                 │     │                 │
│                 │◀────│  3. JWT Token   │     │                 │
│                 │     │                 │     │                 │
│  4. setAuth()   │─────────────────────────────▶ 5. Verify JWT  │
│                 │     │                 │     │                 │
│  6. API calls   │─────────────────────────────▶ 7. User-scoped │
│     with JWT    │     │                 │     │    queries      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Database Schema Changes

The following schema changes were made for auth:

```typescript
// New users table
users: defineTable({
  clerkId: v.string(),
  email: v.optional(v.string()),
  name: v.optional(v.string()),
  imageUrl: v.optional(v.string()),
}).index("by_clerk_id", ["clerkId"]),

// Added to trips table
trips: defineTable({
  userId: v.string(),  // NEW: Clerk user ID
  name: v.string(),
  // ... other fields
}).index("by_user", ["userId"]),
```

## Testing Without Clerk

If you haven't configured Clerk yet, the app will:

1. Skip authentication checks
2. Show the trips screen directly
3. All trips will be shared (no user isolation)

To enable auth, complete the setup steps above and add `CLERK_PUBLISHABLE_KEY` to your `.env` file.

## Troubleshooting

### "Not authenticated" errors

- Ensure `CLERK_PUBLISHABLE_KEY` is set in `.env`
- Check that Clerk is properly configured in the Convex dashboard
- Verify the domain in `auth.config.ts` matches your Clerk issuer URL

### Token not syncing to Convex

- Check the console for "Error syncing token to Convex" messages
- Ensure ConvexService is initialized before AuthService

### User data not saving

- Check the Convex dashboard for errors in the `users:store` mutation
- Verify the `users` table schema matches the expected format
