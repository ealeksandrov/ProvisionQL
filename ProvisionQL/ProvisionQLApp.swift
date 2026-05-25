//
//  ProvisionQLApp.swift
//  ProvisionQL
//
//  Created by Evgeny Aleksandrov

import AppKit
import SwiftUI

@main
struct ProvisionQLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(model: appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = HostAppModel()

    func application(_: NSApplication, open urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        Task {
            await model.previewRequested(for: url)
        }
    }
}
