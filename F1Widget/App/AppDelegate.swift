//
//  AppDelegate.swift
//  F1Widget
//
//  Hybrid app lifecycle: when the user closes the last window the dock icon
//  disappears but the menu bar item stays. Quit from the menu bar popover
//  ("Quit" button) or via ⌘Q fully terminates the process.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Keep the process alive after the last window closes — menu bar item stays.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    /// When the main dashboard window closes, hide the Dock icon so the
    /// app effectively lives in the menu bar only.
    @objc private func windowWillClose(_ note: Notification) {
        // Switch to accessory after a beat so any other windows can react first.
        DispatchQueue.main.async {
            let stillVisible = NSApp.windows.contains { w in
                w.isVisible && w.canBecomeMain && !(w is NSPanel)
            }
            if !stillVisible {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    /// Clicking the (now-absent) Dock icon re-opens the window. Also covers
    /// the "Open App" path from the menu bar popover via NSApp.activate.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        promoteToRegularAndShow()
        return true
    }

    /// Bring the dock icon back and surface the main window.
    func promoteToRegularAndShow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
