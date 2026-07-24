import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Uses Apple Intelligence on-device when it is available. All failures fall
/// back to the deterministic parser, so the app remains usable everywhere.
enum LocalEventIntelligence {
    static func availabilityText() -> String {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else { return "需要较新的 macOS" }
        switch SystemLanguageModel.default.availability {
        case .available:
            return "本地模型可用"
        case .unavailable(.modelNotReady):
            return "本地模型正在下载或准备"
        case .unavailable(.deviceNotEligible):
            return "此 Mac 不支持 Apple 智能"
        case .unavailable:
            return "本地模型当前不可用"
        }
        #else
        return "当前 Xcode 不支持本地模型"
        #endif
    }

    static func parse(_ input: String, now: Date, calendar: Calendar) async -> NewEvent? {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession(instructions: """
                You extract a concise calendar event from short Chinese text.
                Return the action as the title without a location. Return a location only if stated.
                Generate an accurate day offset from the supplied reference date. Use the 24-hour clock.
                The summary MUST be either two Chinese characters or the lowercase text ddl.
                """)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd HH:mm ZZZZ"
            let prompt = "Reference local date/time: \(formatter.string(from: now)). Calendar command: \(input)"
            let response = try await session.respond(to: prompt, generating: GeneratedEvent.self)
            let draft = response.content
            let baseDay = calendar.startOfDay(for: now)
            guard let day = calendar.date(byAdding: .day, value: draft.dayOffset, to: baseDay) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = draft.hour
            components.minute = draft.minute
            let start = draft.isAllDay ? day : (calendar.date(from: components) ?? day)
            let end = draft.isAllDay ? (calendar.date(byAdding: .day, value: 1, to: day) ?? day) : (calendar.date(byAdding: .hour, value: 1, to: start) ?? start)
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = cleanedSummary(draft.summary)
            return NewEvent(
                title: title,
                startDate: start,
                endDate: end,
                calendarTitle: nil,
                location: location.isEmpty ? nil : location,
                isAllDay: draft.isAllDay,
                statusSummary: summary
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func cleanedSummary(_ summary: String) -> String? {
        let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return cleaned.lowercased() == "ddl" ? "ddl" : String(cleaned.prefix(2))
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable(description: "A structured calendar event parsed from a short Chinese command.")
private struct GeneratedEvent {
    @Guide(description: "The event action or title, without location or date/time words.")
    var title: String

    @Guide(description: "The event location. Use an empty string if none is specified.")
    var location: String

    @Guide(description: "Number of days relative to the supplied reference local date. Today is 0, tomorrow is 1.")
    var dayOffset: Int

    @Guide(description: "24-hour local start hour.", .range(0...23))
    var hour: Int

    @Guide(description: "Local start minute.", .range(0...59))
    var minute: Int

    @Guide(description: "True only when the command explicitly requests an all-day event.")
    var isAllDay: Bool

    @Guide(description: "Status bar summary: at most two Chinese characters, or ddl for a deadline.")
    var summary: String
}
#endif
