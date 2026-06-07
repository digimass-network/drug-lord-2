#!/bin/bash
# Build DrugLord2.app — a tiny native macOS WKWebView wrapper around index.html.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
APP="$ROOT/DrugLord2.app"
CON="$APP/Contents"

echo "Cleaning…"
rm -rf "$APP"
mkdir -p "$CON/MacOS" "$CON/Resources"

echo "Bundling game…"
cp "$ROOT/index.html" "$CON/Resources/index.html"
cp "$HERE/Info.plist" "$CON/Info.plist"

echo "Compiling Swift…"
swiftc -O "$HERE/main.swift" -o "$CON/MacOS/DrugLord2" \
  -framework Cocoa -framework WebKit -framework Network
chmod +x "$CON/MacOS/DrugLord2"

# ad-hoc code signature so Gatekeeper lets it run locally without the "damaged" error
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Built: $APP"
