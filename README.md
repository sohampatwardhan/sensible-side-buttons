# Sensible Side Buttons Fork

<img src="icon.png" width=150 />

This fork maintains Sensible Side Buttons for current macOS releases, with the app rebuilt around a Swift/AppKit entry point and release builds available for Apple Silicon and Universal macOS binaries.

The original Sensible Side Buttons app was created by Alexei Baboulevitch. This fork preserves the original app idea and credits the original author for the utility and its underlying behavior.

## Fork Changes

- Updated the app version to 2.0.
- Reworked the menu bar app shell in Swift while keeping the event-tap behavior focused and native.
- Added Apple Silicon and Universal release binaries.
- Enabled Hardened Runtime for distribution builds.
- Removed unfinished Control Center widget work.
- Updated deprecated timing APIs used by the touch event shim.
- Linked the menu bar item to this fork's GitHub repository.

## Downloads

Release binaries are available from this repository's [GitHub Releases page](https://github.com/sohampatwardhan/sensible-side-buttons/releases/tag/v2.0):

- Apple Silicon: [`Sensible-Side-Buttons-2.0-arm64.zip`](https://github.com/sohampatwardhan/sensible-side-buttons/releases/download/v2.0/Sensible-Side-Buttons-2.0-arm64.zip)
- Universal: [`Sensible-Side-Buttons-2.0-universal.zip`](https://github.com/sohampatwardhan/sensible-side-buttons/releases/download/v2.0/Sensible-Side-Buttons-2.0-universal.zip) for Intel and Apple Silicon Macs

System requirements:

- macOS 12.0 Monterey

The updated 2.0 app bundles are substantially smaller than the original Intel application. The Apple Silicon build is about 690 KB, and the Universal build is about 804 KB, compared with about 1.3 MB for the original Intel app.

> [!IMPORTANT]
> These binaries are not notarized. On first launch, macOS Gatekeeper may block the app from opening. To override Gatekeeper, go to System Settings > Privacy & Security. Under Security, you will have the option to whitelist the app.

***

macOS mostly ignores the M4/M5 mouse buttons, commonly used for navigation. Third-party apps can bind them to ⌘+[ and ⌘+], but this only works in a small number of apps and feels janky. With this tool, your side buttons will simulate 3-finger swipes, allowing you to navigate almost any window with a history. As seen in the Logitech MX Master!

Extensive information on this tweak can be found here: http://sensible-side-buttons.archagon.net

To ensure SensibleSideButtons opens whenever you start your computer:

1. Go to System Preferences
1. Click Users & Groups
1. Click your username in the left panel
1. Click Login Items at the top
1. Click the plus button at the bottom
1. Go to wherever you put the app (probably your Applications folder) and double-click it
