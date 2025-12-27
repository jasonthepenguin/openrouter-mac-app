//
//  AppDelegate.swift
//  OpenRouterChat
//
//  Created by Jason Botterill on 27/12/2025.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var contentView: ContentView?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        registerHotKey()
    }

    private func setupWindow() {
        contentView = ContentView()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window?.contentView = NSHostingView(rootView: contentView!)
        window?.title = "OpenRouter Chat"
        window?.center()
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.isReleasedWhenClosed = false
        window?.makeKeyAndOrderFront(nil)
    }

    private func registerHotKey() {
        // Option + Space
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) &&
               !event.modifierFlags.contains(.command) &&
               !event.modifierFlags.contains(.control) &&
               event.keyCode == 49 { // 49 = Space
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) &&
               !event.modifierFlags.contains(.command) &&
               !event.modifierFlags.contains(.control) &&
               event.keyCode == 49 { // 49 = Space
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
                return nil
            }
            return event
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showAndFocusWindow()
        return true
    }

    func showAndFocusWindow() {
        if window == nil {
            setupWindow()
        }

        positionWindowBottomCenter()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.post(name: .focusTextField, object: nil)
    }

    private func positionWindowBottomCenter() {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size

        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y = screenFrame.origin.y + 50 // 50pt from bottom

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func toggleWindow() {
        if let window = window, window.isVisible {
            window.orderOut(nil)
        } else {
            showAndFocusWindow()
            NotificationCenter.default.post(name: .newChat, object: nil)
        }
    }
}

extension Notification.Name {
    static let toggleWindow = Notification.Name("toggleWindow")
    static let focusTextField = Notification.Name("focusTextField")
    static let newChat = Notification.Name("newChat")
}
