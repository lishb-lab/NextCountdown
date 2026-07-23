import Foundation

/// Keeps the optional direct-Google configuration separate from EventKit.
/// Google calendars added in macOS Internet Accounts already sync through EventKit,
/// so no Google secret or token is needed for the default path.
@MainActor
final class GoogleCalendarClient: ObservableObject {
    @Published var clientID: String {
        didSet { UserDefaults.standard.set(clientID, forKey: "googleOAuthClientID") }
    }

    init() {
        clientID = UserDefaults.standard.string(forKey: "googleOAuthClientID") ?? ""
    }
}
