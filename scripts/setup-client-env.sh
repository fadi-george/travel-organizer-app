#!/bin/bash
# Sets up client env symlinks to share with server
#
# Usage:
#   ./setup-client-env.sh           # Auto-detect env file (prefers .env.local)
#   ./setup-client-env.sh prod      # Use .env.prod
#   ./setup-client-env.sh staging   # Use .env.staging

cd "$(dirname "$0")/.." || exit 1

echo "Setting up client environment..."
echo ""

# Helper function to check if API key is valid (not empty or placeholder)
is_valid_api_key() {
  local key="$1"
  if [ -z "$key" ] || [ "$key" = "YOUR_API_KEY_HERE" ]; then
    return 1
  fi
  return 0
}

# Get API key from a specific env file
get_api_key_from_file() {
  grep "^GOOGLE_PLACES_API_KEY=" "$1" 2>/dev/null | cut -d'=' -f2
}

# Find all .env files with valid API keys
find_env_files_with_keys() {
  local files=()
  for f in .env .env.local .env.dev .env.development .env.prod .env.production .env.staging; do
    if [ -f "$f" ]; then
      local key=$(get_api_key_from_file "$f")
      if is_valid_api_key "$key"; then
        files+=("$f")
      fi
    fi
  done
  echo "${files[@]}"
}

# Determine which env file to use
ENV_ARG="$1"
GOOGLE_API_KEY=""
SELECTED_ENV=""

if [ -n "$ENV_ARG" ]; then
  # User specified an environment
  if [ -f ".env.$ENV_ARG" ]; then
    SELECTED_ENV=".env.$ENV_ARG"
  elif [ -f ".env" ] && [ "$ENV_ARG" = "default" ]; then
    SELECTED_ENV=".env"
  else
    echo "❌ Error: .env.$ENV_ARG not found"
    exit 1
  fi
  GOOGLE_API_KEY=$(get_api_key_from_file "$SELECTED_ENV")
  echo "Using environment: $SELECTED_ENV"
else
  # Auto-detect: find all env files with valid API keys
  ENV_FILES=($(find_env_files_with_keys))
  
  if [ ${#ENV_FILES[@]} -eq 0 ]; then
    # No files with valid keys, try to use .env.local or .env anyway
    if [ -f ".env.local" ]; then
      SELECTED_ENV=".env.local"
    elif [ -f ".env" ]; then
      SELECTED_ENV=".env"
    fi
  elif [ ${#ENV_FILES[@]} -eq 1 ]; then
    # Only one file with valid key
    SELECTED_ENV="${ENV_FILES[0]}"
    GOOGLE_API_KEY=$(get_api_key_from_file "$SELECTED_ENV")
    echo "Using environment: $SELECTED_ENV"
  else
    # Multiple files with valid keys - prompt user
    echo "Multiple environment files found with API keys:"
    echo ""
    for i in "${!ENV_FILES[@]}"; do
      echo "  $((i+1))) ${ENV_FILES[$i]}"
    done
    echo ""
    read -p "Select environment [1-${#ENV_FILES[@]}] (default: 1): " choice
    choice=${choice:-1}
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#ENV_FILES[@]} ]; then
      SELECTED_ENV="${ENV_FILES[$((choice-1))]}"
      GOOGLE_API_KEY=$(get_api_key_from_file "$SELECTED_ENV")
      echo ""
      echo "Using environment: $SELECTED_ENV"
    else
      echo "Invalid selection. Using ${ENV_FILES[0]}"
      SELECTED_ENV="${ENV_FILES[0]}"
      GOOGLE_API_KEY=$(get_api_key_from_file "$SELECTED_ENV")
    fi
  fi
fi

echo ""

# Create symlinks in client folder pointing to root env files
cd client || exit 1

# Remove existing files/symlinks if they exist
rm -f .env .env.local 2>/dev/null

# Create symlinks
ln -s ../.env .env
ln -s ../.env.local .env.local

echo "✓ Created client/.env → ../.env"
echo "✓ Created client/.env.local → ../.env.local"

# Set up iOS Google Maps secrets file
IOS_SECRETS="ios/Flutter/Secrets.xcconfig"
IOS_EXAMPLE="ios/Flutter/Secrets.xcconfig.example"
NEEDS_API_KEY=false

# Create iOS secrets file if it doesn't exist
if [ ! -f "$IOS_SECRETS" ]; then
  if [ -f "$IOS_EXAMPLE" ]; then
    cp "$IOS_EXAMPLE" "$IOS_SECRETS"
    echo "✓ Created $IOS_SECRETS from example"
  else
    # Create minimal secrets file
    echo "GOOGLE_MAPS_API_KEY=" > "$IOS_SECRETS"
    echo "✓ Created $IOS_SECRETS"
  fi
fi

# Check current iOS API key
IOS_KEY=$(grep "^GOOGLE_MAPS_API_KEY=" "$IOS_SECRETS" 2>/dev/null | cut -d'=' -f2)

# Update iOS API key if we have one from env and current is invalid
if is_valid_api_key "$GOOGLE_API_KEY"; then
  if ! is_valid_api_key "$IOS_KEY"; then
    # Replace the API key line
    sed -i '' "s|^GOOGLE_MAPS_API_KEY=.*|GOOGLE_MAPS_API_KEY=$GOOGLE_API_KEY|" "$IOS_SECRETS"
    echo "✓ Updated $IOS_SECRETS with API key from .env"
  else
    echo "✓ $IOS_SECRETS has valid API key"
  fi
else
  if ! is_valid_api_key "$IOS_KEY"; then
    NEEDS_API_KEY=true
    echo "⚠️  $IOS_SECRETS needs API key configuration"
  else
    echo "✓ $IOS_SECRETS has valid API key"
  fi
fi

# Set up Android local.properties
ANDROID_PROPS="android/local.properties"
ANDROID_EXAMPLE="android/local.properties.example"

# Create Android properties file if it doesn't exist
if [ ! -f "$ANDROID_PROPS" ]; then
  if [ -f "$ANDROID_EXAMPLE" ]; then
    cp "$ANDROID_EXAMPLE" "$ANDROID_PROPS"
    echo "✓ Created $ANDROID_PROPS from example"
  fi
fi

# Ensure GOOGLE_MAPS_API_KEY line exists in Android properties
if [ -f "$ANDROID_PROPS" ]; then
  if ! grep -q "^GOOGLE_MAPS_API_KEY=" "$ANDROID_PROPS"; then
    echo "" >> "$ANDROID_PROPS"
    echo "# Google Maps API Key" >> "$ANDROID_PROPS"
    echo "GOOGLE_MAPS_API_KEY=" >> "$ANDROID_PROPS"
  fi
  
  # Check current Android API key
  ANDROID_KEY=$(grep "^GOOGLE_MAPS_API_KEY=" "$ANDROID_PROPS" 2>/dev/null | cut -d'=' -f2)
  
  # Update Android API key if we have one from env and current is invalid
  if is_valid_api_key "$GOOGLE_API_KEY"; then
    if ! is_valid_api_key "$ANDROID_KEY"; then
      sed -i '' "s|^GOOGLE_MAPS_API_KEY=.*|GOOGLE_MAPS_API_KEY=$GOOGLE_API_KEY|" "$ANDROID_PROPS"
      echo "✓ Updated $ANDROID_PROPS with API key from .env"
    else
      echo "✓ $ANDROID_PROPS has valid API key"
    fi
  else
    if ! is_valid_api_key "$ANDROID_KEY"; then
      NEEDS_API_KEY=true
      echo "⚠️  $ANDROID_PROPS needs API key configuration"
    else
      echo "✓ $ANDROID_PROPS has valid API key"
    fi
  fi
fi

if [ "$NEEDS_API_KEY" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  ACTION REQUIRED: Configure your Google Maps API key!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. Get an API key from:"
  echo "   https://console.cloud.google.com/apis/credentials"
  echo ""
  echo "2. Enable these APIs in Google Cloud Console:"
  echo "   • Maps SDK for iOS"
  echo "   • Maps SDK for Android"
  echo "   • Geocoding API"
  echo "   • Places API"
  echo ""
  echo "3. Add your API key to:"
  echo "   • iOS:     client/$IOS_SECRETS"
  echo "   • Android: client/$ANDROID_PROPS"
  echo ""
  echo "Replace YOUR_API_KEY_HERE with your actual key."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "Done! Client environment is configured."

