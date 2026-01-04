#!/bin/bash
# Syncs branding assets from root branding/ folder
#
# Source of truth: branding/
# - Copies to: client/assets/branding/ (Flutter needs actual files)
# - Symlinks in: docs/
#
# Usage:
#   ./sync-branding.sh

set -e
cd "$(dirname "$0")/.." || exit 1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Source of truth
BRAND_SOURCE="branding"

# Logo files
LOGO_FILES=(
  "logo.png"
  "logo.svg"
)

# Directories that need copies (Flutter can't use symlinks for assets)
COPY_DIRS=(
  "client/assets/branding"
)

# Directories that can use symlinks
SYMLINK_DIRS=(
  "docs"
)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sync Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "Syncing branding assets..."
echo ""

# Verify source files exist
for file in "${LOGO_FILES[@]}"; do
  if [ ! -f "$BRAND_SOURCE/$file" ]; then
    echo "❌ Error: Source file not found: $BRAND_SOURCE/$file"
    exit 1
  fi
done

echo "Source: $BRAND_SOURCE/"
for file in "${LOGO_FILES[@]}"; do
  echo "  • $file"
done
echo ""

# Copy to directories that need actual files
for dir in "${COPY_DIRS[@]}"; do
  echo "→ Copying to $dir/"
  mkdir -p "$dir"
  
  for file in "${LOGO_FILES[@]}"; do
    cp "$BRAND_SOURCE/$file" "$dir/$file"
    echo "  ✓ $file"
  done
  echo ""
done

# Create symlinks in directories that support them
for dir in "${SYMLINK_DIRS[@]}"; do
  echo "→ Linking in $dir/"
  
  for file in "${LOGO_FILES[@]}"; do
    target="$dir/$file"
    rm -f "$target" 2>/dev/null
    ln -s "../$BRAND_SOURCE/$file" "$target"
    echo "  ✓ $file → ../$BRAND_SOURCE/$file"
  done
  echo ""
done

echo "Done! Branding assets synced."
