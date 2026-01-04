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

# Get all files in branding directory
BRAND_FILES=()
for file in "$BRAND_SOURCE"/*; do
  if [ -f "$file" ]; then
    BRAND_FILES+=("$(basename "$file")")
  fi
done

if [ ${#BRAND_FILES[@]} -eq 0 ]; then
  echo "❌ Error: No files found in $BRAND_SOURCE/"
  exit 1
fi

echo "Source: $BRAND_SOURCE/"
for file in "${BRAND_FILES[@]}"; do
  echo "  • $file"
done
echo ""

# Copy to directories that need actual files
for dir in "${COPY_DIRS[@]}"; do
  echo "→ Copying to $dir/"
  mkdir -p "$dir"
  
  for file in "${BRAND_FILES[@]}"; do
    cp "$BRAND_SOURCE/$file" "$dir/$file"
    echo "  ✓ $file"
  done
  echo ""
done

# Create symlinks in directories that support them
for dir in "${SYMLINK_DIRS[@]}"; do
  echo "→ Linking in $dir/"
  
  for file in "${BRAND_FILES[@]}"; do
    target="$dir/$file"
    rm -f "$target" 2>/dev/null
    ln -s "../$BRAND_SOURCE/$file" "$target"
    echo "  ✓ $file → ../$BRAND_SOURCE/$file"
  done
  echo ""
done

echo "Done! Branding assets synced."
