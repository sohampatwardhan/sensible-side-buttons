//
//  AppDelegate.swift
//
//  SensibleSideButtons
//

import AppKit
import ApplicationServices

private enum DefaultsKey {
    static let shouldBeEnabled = "SBFWasEnabled"
    static let mouseDown = "SBFMouseDown"
    static let swapButtons = "SBFSwapButtons"
}

private enum MenuMode {
    case accessibility
    case normal
}

private enum MenuItemIndex: Int {
    case enabled = 0
    case enabledSeparator
    case triggerOnMouseDown
    case swapButtons
    case optionsSeparator
    case startupHide
    case startupHideInfo
    case startupSeparator
    case repository
    case accessibility
    case linkSeparator
    case quit
}

private let mouseEventCallback: CGEventTapCallBack = { _, type, event, _ in
    let number = event.getIntegerValueField(.mouseEventButtonNumber)
    let down = type == .otherMouseDown
    let defaults = UserDefaults.standard
    let triggerOnMouseDown = defaults.bool(forKey: DefaultsKey.mouseDown)
    let swapButtons = defaults.bool(forKey: DefaultsKey.swapButtons)

    if number == (swapButtons ? 4 : 3) {
        if triggerOnMouseDown == down {
            SwipeSynthesizer.fakeSwipe(.left)
        }
        return nil
    }

    if number == (swapButtons ? 3 : 4) {
        if triggerOnMouseDown == down {
            SwipeSynthesizer.fakeSwipe(.right)
        }
        return nil
    }

    return Unmanaged.passUnretained(event)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var tap: CFMachPort?
    private var menuMode: MenuMode = .normal {
        didSet {
            refreshSettings()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            DefaultsKey.shouldBeEnabled: true,
            DefaultsKey.mouseDown: true,
            DefaultsKey.swapButtons: false
        ])

        UserDefaults.standard.set(true, forKey: DefaultsKey.shouldBeEnabled)

        setupStatusItem()
        startTap(true)
        updateMenuMode()
        refreshSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.isVisible = true
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let activeTap = tap {
            CGEvent.tapEnable(tap: activeTap, enable: false)
            tap = nil
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuMode(prompt: false)
        refreshSettings()
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        menu.addItem(NSMenuItem(title: "Enabled", action: #selector(enabledToggle(_:)), keyEquivalent: "e"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Trigger on Mouse Down", action: #selector(mouseDownToggle(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Swap Buttons", action: #selector(swapToggle(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(hideMenubarItem(_:)), keyEquivalent: ""))

        let hideInfoItem = NSMenuItem(title: "Relaunch application to show again", action: nil, keyEquivalent: "")
        hideInfoItem.isEnabled = false
        menu.addItem(hideInfoItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "GitHub Repository", action: #selector(repository(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Whitelist", action: #selector(accessibility(_:)), keyEquivalent: ""))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        menu.addItem(quit)

        if let button = statusItem.button {
            button.image = menuBarImage(enabled: false)
            button.imagePosition = .imageOnly
            button.toolTip = "Sensible Side Buttons"
            button.setAccessibilityLabel("Sensible Side Buttons")
        }

        statusItem.menu = menu
        statusItem.isVisible = true
        self.statusItem = statusItem
    }

    private func updateMenuMode(prompt: Bool = true) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if accessibilityEnabled {
            let wasWaitingForAccessibility = menuMode == .accessibility
            menuMode = .normal
            if wasWaitingForAccessibility && tap == nil && UserDefaults.standard.bool(forKey: DefaultsKey.shouldBeEnabled) {
                startTap(true)
            }
        } else {
            menuMode = .accessibility
        }
    }

    private func refreshSettings() {
        guard let menu = statusItem?.menu else { return }

        item(.enabled, in: menu)?.state = isTapEnabled ? .on : .off
        item(.triggerOnMouseDown, in: menu)?.state = UserDefaults.standard.bool(forKey: DefaultsKey.mouseDown) ? .on : .off
        item(.swapButtons, in: menu)?.state = UserDefaults.standard.bool(forKey: DefaultsKey.swapButtons) ? .on : .off

        let settingsEnabled = menuMode != .accessibility
        item(.enabled, in: menu)?.isEnabled = settingsEnabled
        item(.triggerOnMouseDown, in: menu)?.isEnabled = settingsEnabled
        item(.swapButtons, in: menu)?.isEnabled = settingsEnabled
        item(.repository, in: menu)?.isHidden = false
        item(.accessibility, in: menu)?.isHidden = menuMode != .accessibility

        item(.startupHide, in: menu)?.isHidden = false
        item(.startupHideInfo, in: menu)?.isHidden = false

        statusItem?.button?.image = menuBarImage(enabled: isTapEnabled)
    }

    private func menuBarImage(enabled: Bool) -> NSImage {
        let assetName = enabled ? "MenuIcon" : "MenuIconDisabled"
        let image = (NSImage(named: assetName)?.copy() as? NSImage)
            ?? NSImage(systemSymbolName: "arrow.left.arrow.right.circle", accessibilityDescription: "Sensible Side Buttons")
            ?? NSImage(size: NSSize(width: 18, height: 18))

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func startTap(_ start: Bool) {
        if start {
            guard tap == nil else { return }

            let eventMask = CGEventMask(1 << CGEventType.otherMouseUp.rawValue) | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            guard let newTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: mouseEventCallback,
                userInfo: nil
            ) else {
                return
            }

            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: newTap, enable: true)
            tap = newTap
        } else if let activeTap = tap {
            CGEvent.tapEnable(tap: activeTap, enable: false)
            tap = nil
        }

        persistTapState()
    }

    private var isTapEnabled: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    private func persistTapState() {
        UserDefaults.standard.set(isTapEnabled, forKey: DefaultsKey.shouldBeEnabled)
    }

    private func item(_ index: MenuItemIndex, in menu: NSMenu?) -> NSMenuItem? {
        guard let menu, index.rawValue < menu.items.count else { return nil }
        return menu.items[index.rawValue]
    }

    @objc private func enabledToggle(_ sender: Any?) {
        let shouldEnable = tap == nil
        UserDefaults.standard.set(shouldEnable, forKey: DefaultsKey.shouldBeEnabled)
        startTap(shouldEnable)
        refreshSettings()
    }

    @objc private func mouseDownToggle(_ sender: Any?) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: DefaultsKey.mouseDown), forKey: DefaultsKey.mouseDown)
        refreshSettings()
    }

    @objc private func swapToggle(_ sender: Any?) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: DefaultsKey.swapButtons), forKey: DefaultsKey.swapButtons)
        refreshSettings()
    }

    @objc private func repository(_ sender: Any?) {
        openURL("https://github.com/sohampatwardhan/sensible-side-buttons")
    }

    @objc private func accessibility(_ sender: Any?) {
        updateMenuMode()
        refreshSettings()
    }

    @objc private func hideMenubarItem(_ sender: Any?) {
        statusItem?.isVisible = false
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(self)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

private enum SwipeSynthesizer {
    enum Direction {
        case left
        case right

        var rawValue: TLInfoSwipeDirection {
            switch self {
            case .left:
                return TLInfoSwipeDirection(kTLInfoSwipeLeft)
            case .right:
                return TLInfoSwipeDirection(kTLInfoSwipeRight)
            }
        }
    }

    static func fakeSwipe(_ direction: Direction) {
        let startInfo: [CFString: Any] = [
            kTLInfoKeyGestureSubtype: kTLInfoSubtypeSwipe,
            kTLInfoKeyGesturePhase: 1
        ]
        let endInfo: [CFString: Any] = [
            kTLInfoKeyGestureSubtype: kTLInfoSubtypeSwipe,
            kTLInfoKeySwipeDirection: direction.rawValue,
            kTLInfoKeyGesturePhase: 4
        ]
        let touches = [] as CFArray

        guard let unmanagedEvent1 = tl_CGEventCreateFromGesture(startInfo as CFDictionary, touches),
              let unmanagedEvent2 = tl_CGEventCreateFromGesture(endInfo as CFDictionary, touches) else {
            return
        }

        let event1 = unmanagedEvent1.takeRetainedValue()
        let event2 = unmanagedEvent2.takeRetainedValue()
        event1.post(tap: .cghidEventTap)
        event2.post(tap: .cghidEventTap)
    }
}
