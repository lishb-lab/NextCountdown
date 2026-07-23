import SwiftUI

struct StatusBarLabel: View {
    let event: CalendarEvent?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let _ = context.date
            Image(systemName: "calendar.badge.clock")
            Text(label(at: context.date))
                .monospacedDigit()
        }
    }

    private func label(at date: Date) -> String {
        guard let event else { return "无日程" }
        let remaining = event.startDate.timeIntervalSince(date)
        if remaining <= 0 { return "无日程" }
        let minutes = Int(remaining / 60)
        if minutes < 60 { return "(minutes)m" }
        if minutes < 24 * 60 { return "(minutes / 60)h (minutes % 60)m" }
        return "(minutes / (24 * 60))d"
    }
}
