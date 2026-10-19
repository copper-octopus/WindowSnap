#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="WindowSnap"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building ${APP_NAME}..."

# Clean previous build
rm -rf "${APP_DIR}"

# Create .app bundle structure
mkdir -p "${MACOS_DIR}"

# Compile Swift source
swiftc \
    -O \
    -framework Cocoa \
    -framework Carbon \
    -o "${MACOS_DIR}/${APP_NAME}" \
    "${SCRIPT_DIR}/Sources/main.swift"

# Copy Info.plist
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "Build complete: ${APP_DIR}"
echo ""
echo "To launch:  open ~/Applications/${APP_NAME}.app"
echo "To quit:    Click the menu bar icon > Quit"
