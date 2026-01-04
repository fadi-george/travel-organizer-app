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
  else
    # Use first file with valid key (prefers .env.local due to search order)
    SELECTED_ENV="${ENV_FILES[0]}"
    GOOGLE_API_KEY=$(get_api_key_from_file "$SELECTED_ENV")
    echo "Using environment: $SELECTED_ENV"
  fi
fi

echo ""

# Create symlinks in client folder pointing to root env files
cd client || exit 1

# Remove existing files/symlinks if they exist
rm -f .env .env.local .env.prod 2>/dev/null

# Only create symlinks for env files that exist in root
if [ -f "../.env" ]; then
  ln -s ../.env .env
  echo "✓ Created client/.env → ../.env"
fi

if [ -f "../.env.local" ]; then
  ln -s ../.env.local .env.local
  echo "✓ Created client/.env.local → ../.env.local"
fi

if [ -f "../.env.prod" ]; then
  ln -s ../.env.prod .env.prod
  echo "✓ Created client/.env.prod → ../.env.prod"
fi

# Check if API key is configured
if is_valid_api_key "$GOOGLE_API_KEY"; then
  echo "✓ GOOGLE_PLACES_API_KEY found in $SELECTED_ENV"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  ACTION REQUIRED: Configure your Google Places API key!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. Get an API key from:"
  echo "   https://console.cloud.google.com/apis/credentials"
  echo ""
  echo "2. Enable these APIs in Google Cloud Console:"
  echo "   • Geocoding API"
  echo "   • Places API"
  echo ""
  echo "3. Add to your .env or .env.local file:"
  echo "   GOOGLE_PLACES_API_KEY=your-api-key-here"
  echo ""
  echo "Note: Map tiles use free OpenStreetMap/CARTO - no API key needed!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "Done! Client environment is configured."
