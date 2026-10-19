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

# Sign with the fixed local identity so Accessibility permission survives rebuilds.
# Looked up by hash because the self-signed certificate is untrusted, which hides it
# from codesign's name matching. See make-signing-cert.sh.
SIGN_ID=$(security find-identity -p codesigning | awk '/"WindowSnap Local Signing"/ {print $2; exit}')
if [ -n "${SIGN_ID}" ]; then
    codesign --force --sign "${SIGN_ID}" --identifier com.emile.windowsnap "${APP_DIR}"
else
    echo "WARNING: no signing identity; run ./make-signing-cert.sh or Accessibility resets on every build"
fi

echo "Build complete: ${APP_DIR}"
echo ""
echo "To launch:  open ~/Applications/${APP_NAME}.app"
echo "To quit:    Click the menu bar icon > Quit"
