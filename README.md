# WindowSnap

A small macOS menu-bar app that snaps the focused window to halves, quarters, the middle of the screen, or full screen with global hotkeys. It is one Swift file, built with `swiftc`, and needs no Xcode project.

## Hotkeys

All hotkeys use Ctrl+Option.

| Key | Does |
|---|---|
| Left / Right | Snap to the left or right half. From a quarter, move to the quarter on the other side. From the outer half or quarter, move to the matching side of the next monitor. |
| Up / Down | Shrink a half to its top or bottom quarter. Press again to grow it back to the half. |
| M | Center. A half becomes a full-height middle column; a quarter becomes a quarter-size window in the middle. Up/Down then step it through the top, middle, and bottom of the middle column. Anything else is centered at its current size. |
| Return | Full screen. Press again to restore the window to where it was. |

WindowSnap remembers each window's snap only while the window stays where it put it. Move or resize it by hand and the next hotkey starts fresh.

## Install

```bash
./make-signing-cert.sh   # once: creates a local code-signing identity
./build.sh               # builds and signs ~/Applications/WindowSnap.app
open ~/Applications/WindowSnap.app
```

Grant Accessibility access when asked (System Settings > Privacy & Security > Accessibility). Without it the menu bar icon dims and its menu links to that setting.

The signing step keeps that permission across rebuilds. macOS identifies an unsigned app by its exact binary, so every rebuild of an unsigned build looks like a new app and loses access.

To start at login, add `~/Applications/WindowSnap.app` under System Settings > General > Login Items. To remove it, run `./uninstall.sh`.

Requires macOS 12 or later.
