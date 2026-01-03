# Authentication Setup

This app uses **Google SSO via Clerk** with **Convex** as the backend.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │     │     Clerk       │     │    Convex       │
│                 │     │                 │     │                 │
│  1. Google SSO  │────▶│  2. OAuth flow  │     │                 │
│                 │     │                 │     │                 │
│                 │◀────│  3. JWT Token   │     │                 │
│                 │     │  (from template)│     │                 │
│  4. setAuth()   │─────────────────────────────▶│ 5. Verify JWT  │
│                 │     │                 │     │                 │
│  6. API calls   │─────────────────────────────▶│ 7. User-scoped │
│     with JWT    │     │                 │     │    queries      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Required Setup

### 1. Clerk Dashboard

1. Create a Clerk application at [clerk.com](https://clerk.com)
2. Enable **Google** under SSO Connections
3. Create a **JWT Template** named `convex`:
   - Go to **JWT Templates** → **New template** → **Convex**
   - Name it exactly: `convex`
   - This generates tokens with `aud: "convex"` which Convex requires

### 2. Environment Variables

**Flutter Client - Development** (`client/.env.local`):

```
CLERK_PUBLISHABLE_KEY=pk_test_xxx
CONVEX_URL=https://your-dev-deployment.convex.cloud
```

**Flutter Client - Production** (`client/.env.prod`):

```
CLERK_PUBLISHABLE_KEY=pk_live_xxx
CONVEX_URL=https://your-prod-deployment.convex.cloud
```

> **Note:** The app loads `.env.local` for debug builds and `.env.prod` for release builds (or when using `--dart-define=ENV=prod`).

**Convex** (set via `bunx convex env set`):

```
CLERK_ISSUER_URL=https://your-clerk-domain.clerk.accounts.dev
```

### 3. iOS Deep Links

Add to `ios/Runner/Info.plist` before closing `</dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>clerk-callback</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>clerk.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>
```

### 4. Android Deep Links

Add to `android/app/src/main/AndroidManifest.xml` inside the `<activity>` tag:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="clerk.${applicationId}"/>
</intent-filter>
```

## Production Setup

Production requires additional configuration beyond development:

### 1. Clerk Production Instance

1. **Enable Native API**: Go to **Configure** → **Settings** and enable **"Native applications"** checkbox. This is required for Flutter/mobile apps.

2. **Add Mobile SSO Redirect URL**: Go to **Configure** → **SSO Connections** → scroll to **"Allowlist for mobile SSO redirect"** and add:

   ```
   com.clerk.flutter://callback
   ```

3. **Set up JWT Template**: Ensure the `convex` JWT template exists in your production instance (same as dev).

### 2. Convex Production Deployment

Set the production `CLERK_ISSUER_URL`:

```bash
bunx convex env set CLERK_ISSUER_URL "https://clerk.yourdomain.com" --prod
```

### 3. Deploy Convex

```bash
bunx convex deploy
```

## Common Pitfalls & Fixes

### ❌ "Native API disabled" error (Production)

**Cause**: The Clerk production instance doesn't have Native API enabled. This is required for Flutter/mobile apps.

**Fix**: In Clerk Dashboard → **Configure** → **Settings** → Enable **"Native applications"**.

### ❌ "Redirect url does not match" error (Production)

**Cause**: The mobile SSO redirect URL is not allowlisted in the production Clerk instance.

**Fix**: In Clerk Dashboard → **Configure** → **SSO Connections** → **"Allowlist for mobile SSO redirect"** → Add `com.clerk.flutter://callback`.

### ❌ "Frame load interrupted" error

**Cause**: Missing deep link configuration. After Google OAuth completes, the browser can't redirect back to the app.

**Fix**: Add the iOS `CFBundleURLSchemes` and Android `intent-filter` configurations above.

### ❌ "Not authenticated" error from Convex

**Cause 1**: Token not being awaited before mutation.

```dart
// ❌ Wrong - setAuth is async!
convexService.client.setAuth(token: token);
await convexService.client.mutation(...); // Runs before token is set

// ✅ Correct
await convexService.client.setAuth(token: token);
await convexService.client.mutation(...);
```

**Cause 2**: Wrong JWT audience. Convex expects `aud: "convex"` but Clerk's default session tokens don't have this.

**Fix**: Get tokens from the "convex" JWT template:

```dart
// ❌ Wrong - default token doesn't have correct audience
final token = authState.session?.lastActiveToken?.jwt;

// ✅ Correct - use the convex template
final sessionToken = await authState.sessionToken(templateName: 'convex');
final token = sessionToken.jwt;
```

### ❌ Consent screen shows every time

**Cause**: Using Clerk's shared development credentials instead of custom Google OAuth credentials.

**Fix**:

1. Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/)
2. Add Clerk's redirect URI to authorized redirect URIs
3. Enable "Use custom credentials" in Clerk Dashboard and paste Client ID/Secret

### ❌ "accounts.dev" shown instead of app name

**Cause**: Google OAuth consent screen not configured.

**Fix**: In Google Cloud Console → OAuth consent screen:

- Set **App name** to your app name
- Add **User support email**
- Save and publish (Testing mode is fine for development)

## Convex Auth Config

`server/convex/auth.config.ts`:

```typescript
export default {
  providers: [
    {
      domain: process.env.CLERK_ISSUER_URL,
      applicationID: "convex",
    },
  ],
};
```

The `applicationID: "convex"` must match the JWT template name in Clerk.

## Token Flow in Code

1. **Sign in** (`login_screen.dart`):

   ```dart
   await ClerkAuth.of(context).ssoSignIn(context, clerk.Strategy.oauthGoogle);
   ```

2. **Get token from template** (`main.dart`):

   ```dart
   final sessionToken = await authState.sessionToken(templateName: 'convex');
   ```

3. **Set auth on Convex client** (`auth_service.dart`):

   ```dart
   await convexService.client.setAuth(token: token);
   ```

4. **Store user in Convex** (`auth_service.dart`):
   ```dart
   await convexService.client.mutation(name: 'users:store', args: {});
   ```

## Testing

1. Run Convex: `bunx convex dev`
2. Run Flutter: `flutter run`
3. Sign in with Google
4. Check Convex dashboard for user in `users` table
