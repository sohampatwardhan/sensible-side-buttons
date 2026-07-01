//
//  SensibleSideButtonsApp.swift
//
//  SensibleSideButtons
//

import SwiftUI

@main
struct SensibleSideButtonsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
