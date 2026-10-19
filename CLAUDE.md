# WindowSnap

macOS menu-bar utility for snapping windows with global hotkeys. Built with Swift using Carbon hotkey APIs and the Accessibility framework.

## Project Structure

- `Sources/main.swift` — Single-file app: hotkey registration, window snapping, menu bar UI
- `Info.plist` — App bundle config (`LSUIElement: true` for menu-bar-only)
- `build.sh` — Compiles with `swiftc` and assembles `.app` bundle into `~/Applications/`
- `uninstall.sh` — Stops running app and removes the `.app` bundle
- `make-signing-cert.sh` — One-time: creates the self-signed "WindowSnap Local Signing" identity that `build.sh` signs with

## Hotkeys

- `Ctrl+Option+Left` — Snap to left half (from a right quarter, moves to the matching left quarter; from the left half, moves to the right half of the monitor to the left)
- `Ctrl+Option+Right` — Snap to right half (mirror of Left)
- `Ctrl+Option+Up` — Shrink a half to its top quarter; pressed again (or Left/Right toward its side), grows back to the half
- `Ctrl+Option+Down` — Same for the bottom quarter
- `Ctrl+Option+Return` — Full screen; pressed again, restores the frame from before
- `Ctrl+Option+C` — Center on its screen, keeping the size

Snap state is kept per window in memory and only trusted while the window's frame still matches what WindowSnap set, so a manual move or resize resets it.

## Build & Run

```bash
./build.sh              # Build to ~/Applications/WindowSnap.app
open ~/Applications/WindowSnap.app
```

## Key Details

- Uses Carbon `RegisterEventHotKey` for global hotkeys (AppKit doesn't support global shortcuts)
- Requires Accessibility permission (prompted on first launch). Without it the menu bar icon dims, the menu shows a link to Settings, and a hotkey press opens Settings
- Signed with a fixed local identity so the permission survives rebuilds; an unsigned build is a new app to macOS every time
- Snaps on the screen under the window's center, not `NSScreen.main`, and sets size, position, size so cross-monitor moves are not clamped
- Coordinate conversion: NSScreen (bottom-left origin) to AX (top-left origin) in `snapFocusedWindow`
