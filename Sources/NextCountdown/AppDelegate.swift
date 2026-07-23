import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let calendar = CalendarStore()
    let google = GoogleCalendarClient()
    private var statusBar: StatusBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(calendar: calendar, google: google)
        enableLaunchAtLoginIfNeeded()
    }

    private func enableLaunchAtLoginIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "didConfigureLaunchAtLogin") else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "didConfigureLaunchAtLogin")
        } catch {
            // It still works normally when launched outside /Applications; the
            // user can move it to Applications and relaunch to enable this.
            NSLog("Could not register launch at login: %@", error.localizedDescription)
        }
    }
}
