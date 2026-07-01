//
//  AppDelegate.swift
//
//  SensibleSideButtons
//

import AppKit
import ApplicationServices
import SwiftUI

private enum DefaultsKey {
    static let wasEnabled = "SBFWasEnabled"
    static let mouseDown = "SBFMouseDown"
    static let donated = "SBFDonated"
    static let swapButtons = "SBFSwapButtons"
}

private enum MenuMode {
    case accessibility
    case donation
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
    case aboutText
    case aboutSeparator
    case donate
    case website
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
            refreshAboutView()
            refreshSettings()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            DefaultsKey.wasEnabled: true,
            DefaultsKey.mouseDown: true,
            DefaultsKey.donated: false,
            DefaultsKey.swapButtons: false
        ])

        setupStatusItem()
        startTap(UserDefaults.standard.bool(forKey: DefaultsKey.wasEnabled))
        updateMenuMode()
        refreshSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.isVisible = true
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        startTap(false)
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

        let aboutItem = NSMenuItem(title: "Text", action: nil, keyEquivalent: "")
        aboutItem.view = NSHostingView(rootView: AboutMenuView(mode: menuMode))
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let appName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "SensibleSideButtons"
        menu.addItem(NSMenuItem(title: "\(appName) Website", action: #selector(donate(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "\(appName) Website", action: #selector(website(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Whitelist", action: #selector(accessibility(_:)), keyEquivalent: ""))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = .command
        menu.addItem(quit)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func updateMenuMode(prompt: Bool = true) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if accessibilityEnabled {
            menuMode = UserDefaults.standard.bool(forKey: DefaultsKey.donated) ? .normal : .donation
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
        item(.donate, in: menu)?.isHidden = menuMode != .donation
        item(.website, in: menu)?.isHidden = menuMode == .donation
        item(.accessibility, in: menu)?.isHidden = menuMode != .accessibility

        item(.startupHide, in: menu)?.isHidden = false
        item(.startupHideInfo, in: menu)?.isHidden = false

        statusItem?.button?.image = NSImage(named: isTapEnabled ? "MenuIcon" : "MenuIconDisabled")
    }

    private func refreshAboutView() {
        guard let aboutItem = item(.aboutText, in: statusItem?.menu) else { return }
        aboutItem.view = NSHostingView(rootView: AboutMenuView(mode: menuMode))
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
                persistTapState()
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
        UserDefaults.standard.set(isTapEnabled, forKey: DefaultsKey.wasEnabled)
    }

    private func item(_ index: MenuItemIndex, in menu: NSMenu?) -> NSMenuItem? {
        guard let menu, index.rawValue < menu.items.count else { return nil }
        return menu.items[index.rawValue]
    }

    @objc private func enabledToggle(_ sender: Any?) {
        startTap(tap == nil)
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

    @objc private func donate(_ sender: Any?) {
        openURL("http://sensible-side-buttons.archagon.net#donations")
        UserDefaults.standard.set(true, forKey: DefaultsKey.donated)
        updateMenuMode()
        refreshSettings()
    }

    @objc private func website(_ sender: Any?) {
        openURL("http://sensible-side-buttons.archagon.net")
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

private struct AboutMenuView: View {
    let mode: MenuMode

    private var appDescription: String {
        let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "SensibleSideButtons"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return "\(name) \(version)"
    }

    private var message: String {
        switch mode {
        case .accessibility:
            return "Uh-oh! It looks like \(appDescription) is not whitelisted in the Accessibility panel of your Security & Privacy System Preferences. This app needs to be on the Accessibility whitelist in order to process global mouse events. Please open the Accessibility panel below and add the app to the whitelist."
        case .donation:
            return "Thanks for using \(appDescription)!\nIf you find this utility useful, please consider making a purchase through the Amazon affiliate link on the website below. It won't cost you an extra cent!"
        case .normal:
            return "Thanks for using \(appDescription)!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .foregroundStyle(mode == .accessibility ? .red : .secondary)
                .font(.system(size: 13))
                .textSelection(.disabled)
                .fixedSize(horizontal: false, vertical: true)

            Text("Copyright (C) 2018 Alexei Baboulevitch.")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        }
        .frame(width: 286, alignment: .leading)
        .padding(.leading, 17)
        .padding(.vertical, 4)
    }
}
