import Foundation

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarName: String
    let isAllDay: Bool
    let statusSummary: String?
}

struct NewEvent: Equatable {
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarTitle: String?
    var location: String?
    var isAllDay: Bool
    var statusSummary: String?
}

enum CalendarAccessState: Equatable {
    case unknown
    case denied
    case granted
    case error(String)
}

enum ParseError: LocalizedError {
    case unableToFindTime

    var errorDescription: String? {
        "我还没找到时间。试试：\"明天 14:30 和小王开会 1 小时\"。"
    }
}
