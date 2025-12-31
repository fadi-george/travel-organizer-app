#!/bin/bash
# Sets up client env symlinks to share with server

cd "$(dirname "$0")/.." || exit 1

echo "Setting up client environment symlinks..."

# Create symlinks in client folder pointing to root env files
cd client || exit 1

# Remove existing files/symlinks if they exist
rm -f .env .env.local 2>/dev/null

# Create symlinks
ln -s ../.env .env
ln -s ../.env.local .env.local

echo "✓ Created client/.env → ../.env"
echo "✓ Created client/.env.local → ../.env.local"
echo ""
echo "Done! Client and server now share the same env files."

