//
//  OpenRouterChatApp.swift
//  OpenRouterChat
//
//  Created by Jason Botterill on 27/12/2025.
//

import SwiftUI

@main
struct OpenRouterChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .toggleWindow,
            object: nil,
            queue: .main
        ) { _ in
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.toggleWindow()
            }
        }
    }
}
