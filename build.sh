#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/Quickrun.xcodeproj"
SCHEME="Quickrun"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Release"
APP_PATH="$APP_DIR/Quickrun.app"
DMG_PATH="$PROJECT_DIR/Quickrun.dmg"

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

step()  { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()    { echo -e "${GREEN}✔ $1${NC}"; }
fail()  { echo -e "${RED}✘ $1${NC}"; exit 1; }

# ── 1. Clean ─────────────────────────────────────────────────────────────────
step "Cleaning build folder..."
rm -rf "$BUILD_DIR"
rm -f  "$DMG_PATH"
ok "Cleaned"

# ── 2. Release build ─────────────────────────────────────────────────────────
step "Building Release..."
xcodebuild \
  -project "$PROJECT" \
  -scheme  "$SCHEME" \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$APP_DIR" \
  build 2>&1 | grep -E "^(error:|warning:|Build succeeded|BUILD)" || true

# Verify
[ -d "$APP_PATH" ] || fail "Build failed — $APP_PATH not found"
ok "Build complete → $APP_PATH"

# ── 3. Create DMG ────────────────────────────────────────────────────────────
step "Creating DMG..."

# Staging folder with /Applications symlink for drag-to-install
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir  "$STAGING"
cp -R  "$APP_PATH" "$STAGING/"
ln -s  /Applications "$STAGING/Applications"

hdiutil create \
  -volname   "Quickrun" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" > /dev/null

rm -rf "$STAGING"

[ -f "$DMG_PATH" ] || fail "DMG creation failed"
ok "DMG created → $DMG_PATH"

# ── 4. Summary ───────────────────────────────────────────────────────────────
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Quickrun.dmg  •  $DMG_SIZE  •  Ready !${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
