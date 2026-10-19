# WindowSnap

macOS menu-bar utility for snapping windows with global hotkeys. Built with Swift using Carbon hotkey APIs and the Accessibility framework.

## Project Structure

- `Sources/main.swift` — Single-file app: hotkey registration, window snapping, menu bar UI
- `Info.plist` — App bundle config (`LSUIElement: true` for menu-bar-only)
- `build.sh` — Compiles with `swiftc` and assembles `.app` bundle into `~/Applications/`
- `uninstall.sh` — Stops running app and removes the `.app` bundle

## Hotkeys

- `Ctrl+Option+Left` — Snap to left half (from a right quarter, moves to the matching left quarter)
- `Ctrl+Option+Right` — Snap to right half (mirror of Left)
- `Ctrl+Option+Up` — Shrink a half to its top quarter; pressed again (or Left/Right toward its side), grows back to the half
- `Ctrl+Option+Down` — Same for the bottom quarter
- `Ctrl+Option+Return` — Full screen; pressed again, restores the frame from before

Snap state is kept per window in memory and only trusted while the window's frame still matches what WindowSnap set, so a manual move or resize resets it.

## Build & Run

```bash
./build.sh              # Build to ~/Applications/WindowSnap.app
open ~/Applications/WindowSnap.app
```

## Key Details

- Uses Carbon `RegisterEventHotKey` for global hotkeys (AppKit doesn't support global shortcuts)
- Requires Accessibility permission (prompted on first launch)
- Coordinate conversion: NSScreen (bottom-left origin) to AX (top-left origin) in `snapFocusedWindow`
