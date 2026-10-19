#!/bin/bash
set -e

APP_NAME="WindowSnap"
APP_DIR="$HOME/Applications/${APP_NAME}.app"

echo "Uninstalling ${APP_NAME}..."

# Quit the app if running
if pgrep -x "${APP_NAME}" > /dev/null 2>&1; then
    echo "Stopping ${APP_NAME}..."
    killall "${APP_NAME}" 2>/dev/null || true
    sleep 1
fi

# Remove the app bundle
if [ -d "${APP_DIR}" ]; then
    rm -rf "${APP_DIR}"
    echo "Removed ${APP_DIR}"
else
    echo "App not found at ${APP_DIR} (already removed?)"
fi

echo ""
echo "Uninstall complete."
echo ""
echo "Optional manual steps:"
echo "  1. Remove source files:  rm -rf ~/Developer/${APP_NAME}"
echo "  2. Revoke Accessibility: System Settings > Privacy & Security > Accessibility"
echo "     Find and remove ${APP_NAME} from the list."
