import Foundation

/// A small offline parser for common Chinese scheduling phrases.
/// Set an OpenAI-compatible endpoint in Settings to use a more capable parser later.
enum NaturalLanguageParser {
    static func parsePreferred(_ input: String, now: Date = .now, calendar: Calendar = .current) async throws -> NewEvent {
        // Calendar dates written explicitly (for example, "9月2日") should never
        // depend on the language model estimating a day offset. Keep the model
        // for the title, location and compact summary, but pin its result to the
        // date the person actually typed.
        let typedDate = explicitDate(in: input, now: now, calendar: calendar)
        if let localModelEvent = await LocalEventIntelligence.parse(input, now: now, calendar: calendar) {
            return typedDate.map { applying(date: $0, to: localModelEvent, calendar: calendar) } ?? localModelEvent
        }
        return try parse(input, now: now, calendar: calendar)
    }

    static func parse(_ input: String, now: Date = .now, calendar: Calendar = .current) throws -> NewEvent {
        var date = calendar.startOfDay(for: now)
        let isAllDay = input.contains("全天")
        if input.contains("明天") {
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        } else if input.contains("后天") {
            date = calendar.date(byAdding: .day, value: 2, to: date)!
        } else if let weekday = chineseWeekday(in: input), let next = calendar.nextDate(after: now, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTimePreservingSmallerComponents) {
            date = calendar.startOfDay(for: next)
        } else if let explicit = explicitDate(in: input, now: now, calendar: calendar) {
            date = explicit
        } else if !input.contains("今天") && !hasTime(input) && !isAllDay {
            throw ParseError.unableToFindTime
        }

        if isAllDay {
            let end = calendar.date(byAdding: .day, value: 1, to: date)!
            let location = location(in: input)
            return NewEvent(title: cleanedTitle(input, location: location), startDate: date, endDate: end, calendarTitle: nil, location: location, isAllDay: true, statusSummary: nil)
        }
        guard let time = time(in: input) else { throw ParseError.unableToFindTime }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        guard var start = calendar.date(from: components) else { throw ParseError.unableToFindTime }
        // Only implicit dates roll forward. An explicit "9月2日" must retain the
        // date that was typed, even if its time has already passed.
        if start < now && !input.contains("今天") && explicitDate(in: input, now: now, calendar: calendar) == nil {
            start = calendar.date(byAdding: .day, value: 1, to: start)!
        }
        let duration = durationMinutes(in: input) ?? 60
        let end = calendar.date(byAdding: .minute, value: duration, to: start)!
        let location = location(in: input)
        let title = cleanedTitle(input, location: location)
        return NewEvent(title: title, startDate: start, endDate: end, calendarTitle: nil, location: location, isAllDay: false, statusSummary: nil)
    }

    private static func hasTime(_ text: String) -> Bool { time(in: text) != nil }

    private static func time(in text: String) -> (hour: Int, minute: Int)? {
        let pattern = "(?:下午|晚上|中午|早上|上午)?\\s*(\\d{1,2})(?::|点)(\\d{1,2})?"
        guard let values = captureGroups(pattern: pattern, in: text),
              let hour = Int(values[0]), hour < 24 else { return nil }
        let minute = values.count > 1 ? Int(values[1]) ?? 0 : 0
        var normalizedHour = hour
        let range = values.last ?? ""
        if (range.contains("下午") || range.contains("晚上")) && hour < 12 { normalizedHour += 12 }
        if range.contains("中午") && hour < 11 { normalizedHour += 12 }
        return (normalizedHour, minute)
    }

    private static func durationMinutes(in text: String) -> Int? {
        let pattern = "(\\d+(?:\\.\\d+)?)\\s*(小时|分钟|分)"
        guard let values = captureGroups(pattern: pattern, in: text), let value = Double(values[0]) else { return nil }
        return values[1] == "小时" ? Int(value * 60) : Int(value)
    }

    private static func explicitDate(in text: String, now: Date, calendar: Calendar) -> Date? {
        let pattern = "(\\d{1,2})月(\\d{1,2})日?"
        guard let values = captureGroups(pattern: pattern, in: text), let month = Int(values[0]), let day = Int(values[1]) else { return nil }
        var components = calendar.dateComponents([.year], from: now)
        components.month = month; components.day = day
        guard let date = calendar.date(from: components) else { return nil }

        // A month/day earlier than today is normally the next occurrence of that
        // date. This makes "1月5日" entered in August mean next January.
        if date < calendar.startOfDay(for: now) {
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
        return date
    }

    private static func applying(date: Date, to event: NewEvent, calendar: Calendar) -> NewEvent {
        var corrected = event
        let day = calendar.startOfDay(for: date)
        if event.isAllDay {
            corrected.startDate = day
            corrected.endDate = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return corrected
        }

        let time = calendar.dateComponents([.hour, .minute, .second], from: event.startDate)
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        let correctedStart = calendar.date(from: components) ?? day
        let duration = max(0, event.endDate.timeIntervalSince(event.startDate))
        corrected.startDate = correctedStart
        corrected.endDate = correctedStart.addingTimeInterval(duration)
        return corrected
    }

    private static func chineseWeekday(in text: String) -> Int? {
        let pairs: [(String, Int)] = [("周日", 1), ("周一", 2), ("周二", 3), ("周三", 4), ("周四", 5), ("周五", 6), ("周六", 7), ("星期日", 1), ("星期一", 2), ("星期二", 3), ("星期三", 4), ("星期四", 5), ("星期五", 6), ("星期六", 7)]
        return pairs.first(where: { text.contains($0.0) })?.1
    }

    /// Recognises phrases such as “在 tamagawa 开会” and “于玉川见面”.
    /// “@地点” is also accepted for unambiguous input.
    private static func location(in text: String) -> String? {
        let patterns = [
            "@\\s*([^，。,.\\s]+)",
            "(?:在|于)\\s*([^，。,.]+?)(?=(?:开会|会议|见面|吃饭|上课|就诊|面试|讨论|汇报|拜访|$))"
        ]
        for pattern in patterns {
            guard let values = captureGroups(pattern: pattern, in: text) else { continue }
            let location = values[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if !location.isEmpty { return location }
        }
        return nil
    }

    private static func cleanedTitle(_ text: String, location: String?) -> String {
        var title = text
        let patterns = ["明天", "后天", "今天", "全天", "周[一二三四五六日]", "星期[一二三四五六日]", "\\d{1,2}月\\d{1,2}日?", "(?:下午|晚上|中午|早上|上午)?\\s*\\d{1,2}(?::|点)\\d{0,2}", "\\d+(?:\\.\\d+)?\\s*(?:小时|分钟|分)", "提醒我", "帮我", "安排"]
        for pattern in patterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        if let location {
            title = title.replacingOccurrences(of: "@\\s*\(NSRegularExpression.escapedPattern(for: location))", with: "", options: .regularExpression)
            title = title.replacingOccurrences(of: "(?:在|于)\\s*\(NSRegularExpression.escapedPattern(for: location))", with: "", options: .regularExpression)
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名日程" : title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns capture groups followed by the full matched text. NSRegularExpression
    /// keeps this parser compatible with the Swift 5 language mode used by SPM.
    private static func captureGroups(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        var values: [String] = []
        for index in 1..<result.numberOfRanges {
            let range = result.range(at: index)
            values.append(range.location == NSNotFound ? "" : String(text[Range(range, in: text)!]))
        }
        values.append(String(text[Range(result.range, in: text)!]))
        return values
    }
}
