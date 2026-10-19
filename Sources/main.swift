import Cocoa
import Carbon

enum Snap {
    case leftHalf, rightHalf, full
    case topLeft, bottomLeft, topRight, bottomRight
    // Middle column: full height, or a quarter-size window at its top, middle, or bottom
    case centerColumn, centerTop, centerMiddle, centerBottom
}

// AXUIElement is a CFType, so window identity is CFEqual/CFHash, not pointer identity.
struct WindowKey: Hashable {
    let element: AXUIElement
    static func == (a: WindowKey, b: WindowKey) -> Bool { CFEqual(a.element, b.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

struct WindowState {
    var snap: Snap?
    var frame: CGRect               // AX frame the window ended up at after the snap
    var beforeFull: (snap: Snap?, frame: CGRect)?
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRefs: [EventHotKeyRef?] = []
    var windowStates: [WindowKey: WindowState] = [:]
    var permissionItem: NSMenuItem!
    var permissionSeparator: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        checkAccessibility()
        installHotKeyHandler()
        registerHotKeys()

        // Permission can be revoked or granted while running, so keep the menu honest.
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    // MARK: - Menu Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "\u{2B1A}"
        }

        let menu = NSMenu()
        permissionItem = NSMenuItem(title: "Accessibility access needed: open Settings",
                                    action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        permissionSeparator = .separator()
        menu.addItem(permissionItem)
        menu.addItem(permissionSeparator)
        menu.addItem(withTitle: "WindowSnap", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Left Half      \u{2303}\u{2325}\u{2190}", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Right Half    \u{2303}\u{2325}\u{2192}", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Top Quarter   \u{2303}\u{2325}\u{2191}", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Bottom Quarter \u{2303}\u{2325}\u{2193}", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Full Screen / Restore  \u{2303}\u{2325}\u{23CE}", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Center         \u{2303}\u{2325}M", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSLog("WindowSnap: Accessibility permission required. Please grant access in System Settings.")
        }
        refreshPermissionStatus()
    }

    // Without access every hotkey silently does nothing, so dim the icon and say why.
    private func refreshPermissionStatus() {
        let trusted = AXIsProcessTrusted()
        statusItem.button?.alphaValue = trusted ? 1.0 : 0.35
        permissionItem.isHidden = trusted
        permissionSeparator.isHidden = trusted
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Global Hotkeys (Carbon)

    private func installHotKeyHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
                guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                delegate.handleHotKey(id: hotKeyID.id)
                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            nil
        )
    }

    private func registerHotKeys() {
        let signature = OSType(0x574E5350) // "WNSP"
        let mods = UInt32(controlKey | optionKey)

        register(keyCode: UInt32(kVK_LeftArrow), modifiers: mods, id: 1, signature: signature)
        register(keyCode: UInt32(kVK_RightArrow), modifiers: mods, id: 2, signature: signature)
        register(keyCode: UInt32(kVK_Return), modifiers: mods, id: 3, signature: signature)
        register(keyCode: UInt32(kVK_UpArrow), modifiers: mods, id: 4, signature: signature)
        register(keyCode: UInt32(kVK_DownArrow), modifiers: mods, id: 5, signature: signature)
        register(keyCode: UInt32(kVK_ANSI_M), modifiers: mods, id: 6, signature: signature)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, signature: OSType) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRefs.append(ref)
        } else {
            NSLog("WindowSnap: Failed to register hotkey id=\(id), status=\(status)")
        }
    }

    // MARK: - Window Snapping

    private func handleHotKey(id: UInt32) {
        guard AXIsProcessTrusted() else {
            refreshPermissionStatus()
            openAccessibilitySettings()
            return
        }
        guard let window = focusedWindow(), let current = frame(of: window),
              let screen = screen(containing: current) else { return }
        let visible = screen.visibleFrame
        let key = WindowKey(element: window)

        // A remembered snap only counts if the window has not been moved or resized since.
        var state = windowStates[key]
        if let s = state, !s.frame.isClose(to: current) { state = nil }
        let snap = state?.snap
        let onLeft = current.midX < toAX(visible).midX

        var targetScreen = screen
        let target: Snap
        switch id {
        case 1: // Left: a right quarter moves across; the left half and left quarters move on
                // to the matching right side of the next monitor over, or at the edge, a left
                // quarter grows back to the left half
            let west = adjacentScreen(to: screen, west: true)
            switch snap {
            case .topRight, .centerTop: target = .topLeft
            case .bottomRight, .centerBottom: target = .bottomLeft
            case .leftHalf:
                guard let west = west else { return }
                targetScreen = west
                target = .rightHalf
            case .topLeft, .bottomLeft:
                if let west = west {
                    targetScreen = west
                    target = snap == .topLeft ? .topRight : .bottomRight
                } else {
                    target = .leftHalf
                }
            default: target = .leftHalf
            }
        case 2: // Right
            let east = adjacentScreen(to: screen, west: false)
            switch snap {
            case .topLeft, .centerTop: target = .topRight
            case .bottomLeft, .centerBottom: target = .bottomRight
            case .rightHalf:
                guard let east = east else { return }
                targetScreen = east
                target = .leftHalf
            case .topRight, .bottomRight:
                if let east = east {
                    targetScreen = east
                    target = snap == .topRight ? .topLeft : .bottomLeft
                } else {
                    target = .rightHalf
                }
            default: target = .rightHalf
            }
        case 4: // Up: a top quarter grows back to its half
            switch snap {
            case .topLeft: target = .leftHalf
            case .topRight: target = .rightHalf
            case .leftHalf, .bottomLeft: target = .topLeft
            case .rightHalf, .bottomRight: target = .topRight
            // The middle column steps through its quarter-size slots, then grows back
            case .centerColumn, .centerMiddle: target = .centerTop
            case .centerBottom: target = .centerMiddle
            case .centerTop: target = .centerColumn
            default: target = onLeft ? .topLeft : .topRight
            }
        case 5: // Down
            switch snap {
            case .bottomLeft: target = .leftHalf
            case .bottomRight: target = .rightHalf
            case .leftHalf, .topLeft: target = .bottomLeft
            case .rightHalf, .topRight: target = .bottomRight
            case .centerColumn, .centerMiddle: target = .centerBottom
            case .centerTop: target = .centerMiddle
            case .centerBottom: target = .centerColumn
            default: target = onLeft ? .bottomLeft : .bottomRight
            }
        case 3: // Return: full screen, or a second press restores the frame from before it
            if snap == .full, let before = state?.beforeFull {
                setFrame(of: window, to: before.frame)
                windowStates[key] = WindowState(snap: before.snap, frame: frame(of: window) ?? before.frame)
                return
            }
            target = .full
        case 6: // M: a half becomes the full-height middle column, a quarter a quarter-size
                // window in the middle; anything else keeps its size and is centered
            switch snap {
            case .leftHalf, .rightHalf, .centerColumn: target = .centerColumn
            case .topLeft, .bottomLeft, .topRight, .bottomRight, .centerTop, .centerMiddle, .centerBottom:
                target = .centerMiddle
            default:
                centerKeepingSize(window, current: current, in: visible)
                windowStates[key] = nil
                return
            }
        default:
            return
        }

        setFrame(of: window, to: toAX(rect(for: target, in: targetScreen.visibleFrame)))
        var next = WindowState(snap: target, frame: frame(of: window) ?? current)
        if target == .full { next.beforeFull = (snap, current) }
        windowStates[key] = next
    }

    private func centerKeepingSize(_ window: AXUIElement, current: CGRect, in visible: CGRect) {
        let area = toAX(visible)
        let size = CGSize(width: min(current.width, area.width), height: min(current.height, area.height))
        setFrame(of: window, to: CGRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                                        width: size.width, height: size.height))
    }

    private func rect(for snap: Snap, in v: CGRect) -> CGRect {
        let w = v.width / 2, h = v.height / 2
        // NSScreen coordinates: y grows upward, so the top quarter sits at origin.y + h
        switch snap {
        case .leftHalf:    return CGRect(x: v.minX, y: v.minY, width: w, height: v.height)
        case .rightHalf:   return CGRect(x: v.minX + w, y: v.minY, width: w, height: v.height)
        case .full:        return v
        case .topLeft:     return CGRect(x: v.minX, y: v.minY + h, width: w, height: h)
        case .bottomLeft:  return CGRect(x: v.minX, y: v.minY, width: w, height: h)
        case .topRight:    return CGRect(x: v.minX + w, y: v.minY + h, width: w, height: h)
        case .bottomRight: return CGRect(x: v.minX + w, y: v.minY, width: w, height: h)
        case .centerColumn: return CGRect(x: v.minX + w / 2, y: v.minY, width: w, height: v.height)
        case .centerTop:    return CGRect(x: v.minX + w / 2, y: v.minY + h, width: w, height: h)
        case .centerMiddle: return CGRect(x: v.minX + w / 2, y: v.minY + h / 2, width: w, height: h)
        case .centerBottom: return CGRect(x: v.minX + w / 2, y: v.minY, width: w, height: h)
        }
    }

    // Convert from NSScreen coordinates (bottom-left origin) to AX coordinates (top-left origin)
    private func toAX(_ nsRect: CGRect) -> CGRect {
        let screenHeight = NSScreen.screens[0].frame.height
        return CGRect(x: nsRect.origin.x, y: screenHeight - nsRect.origin.y - nsRect.height,
                      width: nsRect.width, height: nsRect.height)
    }

    // The screen under the window's center. NSScreen.main follows keyboard focus, not
    // the window, so with two monitors it can send a window to the wrong one.
    private func screen(containing axFrame: CGRect) -> NSScreen? {
        let center = CGPoint(x: axFrame.midX, y: axFrame.midY)
        return NSScreen.screens.first { toAX($0.frame).contains(center) } ?? NSScreen.main
    }

    // The nearest monitor wholly to the left (west) or right of this one, if any.
    private func adjacentScreen(to screen: NSScreen, west: Bool) -> NSScreen? {
        let others = NSScreen.screens.filter { $0 != screen }
        if west {
            return others.filter { $0.frame.maxX <= screen.frame.minX + 1 }.max { $0.frame.maxX < $1.frame.maxX }
        }
        return others.filter { $0.frame.minX >= screen.frame.maxX - 1 }.min { $0.frame.minX < $1.frame.minX }
    }

    private func focusedWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else {
            return nil
        }
        return (windowValue as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var posValue: AnyObject?, sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        var position = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private func setFrame(of window: AXUIElement, to axRect: CGRect) {
        var position = axRect.origin
        var size = axRect.size
        guard let posValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }

        // Size, position, size: macOS clamps a move that would leave the old, larger
        // window hanging off a screen, so the first resize makes room and the second
        // corrects whatever the clamp did.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }
}

extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance &&
            abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}

// MARK: - App Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
