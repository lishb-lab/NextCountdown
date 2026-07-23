import EventKit
import Foundation

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var accessState: CalendarAccessState = .unknown
    @Published private(set) var currentEvent: CalendarEvent?
    @Published private(set) var nextEvent: CalendarEvent?
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var iCloudCalendarNames: [String] = []
    @Published var errorMessage: String?

    private let eventStore = EKEventStore()
    private var notificationToken: NSObjectProtocol?

    init() {
        notificationToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        Task { await requestAccessAndRefresh() }
    }

    deinit {
        if let notificationToken { NotificationCenter.default.removeObserver(notificationToken) }
    }

    func requestAccessAndRefresh() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            accessState = granted ? .granted : .denied
            if granted { refresh() }
        } catch {
            accessState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard accessState == .granted else { return }
        iCloudCalendarNames = iCloudCalendars().map(\.title)
        let now = Date()
        guard let queryStart = Calendar.current.date(byAdding: .day, value: -1, to: now),
              let end = Calendar.current.date(byAdding: .day, value: 90, to: now) else { return }
        let predicate = eventStore.predicateForEvents(withStart: queryStart, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "未命名日程",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarName: event.calendar.title,
                    isAllDay: event.isAllDay
                )
            }
        currentEvent = events.first { $0.startDate <= now && $0.endDate > now }
        upcomingEvents = Array(events.filter { $0.startDate > now }.prefix(8))
        nextEvent = upcomingEvents.first
    }

    func create(_ newEvent: NewEvent) throws {
        guard accessState == .granted else { throw NSError(domain: "NextCountdown", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先允许访问日历。"]) }
        let event = EKEvent(eventStore: eventStore)
        event.title = newEvent.location.map { "\(newEvent.title)@\($0)" } ?? newEvent.title
        event.startDate = newEvent.startDate
        event.endDate = newEvent.endDate
        event.isAllDay = newEvent.isAllDay
        event.calendar = iCloudCalendar(named: newEvent.calendarTitle) ?? defaultICloudCalendar() ?? eventStore.defaultCalendarForNewEvents
        event.location = newEvent.location
        try eventStore.save(event, span: .thisEvent)
        refresh()
    }

    func delete(_ event: CalendarEvent) throws {
        guard accessState == .granted else { return }
        guard let ekEvent = eventStore.event(withIdentifier: event.id) else { return }
        try eventStore.remove(ekEvent, span: .thisEvent)
        refresh()
    }

    private func iCloudCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event).filter {
            $0.allowsContentModifications &&
            $0.source.sourceType == .calDAV &&
            $0.source.title.localizedCaseInsensitiveContains("icloud")
        }
    }

    private func iCloudCalendar(named title: String?) -> EKCalendar? {
        guard let title, !title.isEmpty else { return nil }
        return iCloudCalendars().first { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }
    }

    private func defaultICloudCalendar() -> EKCalendar? {
        iCloudCalendar(named: "日历") ?? iCloudCalendars().first
    }
}
