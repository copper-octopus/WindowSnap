# WindowSnap

macOS menu-bar utility for snapping windows with global hotkeys. Built with Swift using Carbon hotkey APIs and the Accessibility framework.

## Project Structure

- `Sources/main.swift` — Single-file app: hotkey registration, window snapping, menu bar UI
- `Info.plist` — App bundle config (`LSUIElement: true` for menu-bar-only)
- `build.sh` — Compiles with `swiftc` and assembles `.app` bundle into `~/Applications/`
- `uninstall.sh` — Stops running app and removes the `.app` bundle
- `README.md` — Public-facing hotkey and install docs; keep in sync with the Hotkeys section below
- `make-signing-cert.sh` — One-time: creates the self-signed "WindowSnap Local Signing" identity that `build.sh` signs with

## Hotkeys

- `Ctrl+Option+Left` — Snap to left half. From a right quarter, moves to the matching left quarter. From the left half or a left quarter, moves to the matching right side of the monitor to the left; with no monitor there, a left quarter grows back to the left half
- `Ctrl+Option+Right` — Snap to right half (mirror of Left)
- `Ctrl+Option+Up` — Shrink a half to its top quarter; pressed again (or Left/Right toward its side), grows back to the half
- `Ctrl+Option+Down` — Same for the bottom quarter
- `Ctrl+Option+Return` — Full screen; pressed again, restores the frame from before
- `Ctrl+Option+M` — Center. A half becomes a full-height middle column; a quarter becomes a quarter-size window in the middle; anything else is centered at its current size
  - From the middle column, Up/Down step through quarter-size top, middle, and bottom slots in the middle column, and pressing past the end grows it back to the column
  - Left/Right from the middle: the column or middle slot goes to that half, the top or bottom slot to that quarter

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
