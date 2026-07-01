# Changelog

## 2.0 - 2026-07-01

- Rebuilt the menu bar app around the Swift/SwiftUI-era app entry point while keeping the event tap behavior in AppKit where appropriate.
- Updated the app for Apple Silicon builds and bumped the app version to 2.0.
- Removed the unfinished Control Center widget integration and related App Group references.
- Updated the menu bar menu to remove the empty informational section and link to the forked GitHub repository.
- Enabled side button support automatically on app launch and after Accessibility permission becomes available.
- Replaced deprecated `AbsoluteToNanoseconds` and `UpTime` usage in `TouchEvents.c` with `mach_absolute_time`.
- Removed empty documentation `@discussion` paragraphs from `IOHIDEventTypes.h`.
