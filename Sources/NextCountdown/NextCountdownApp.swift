import SwiftUI

@main
struct NextCountdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(calendar: appDelegate.calendar, google: appDelegate.google)
        }
    }
}
