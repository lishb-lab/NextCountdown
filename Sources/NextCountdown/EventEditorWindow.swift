import SwiftUI

struct EventEditorView: View {
    let event: CalendarEvent
    @ObservedObject var calendar: CalendarStore
    let close: () -> Void

    @State private var title: String
    @State private var date: Date
    @State private var time: Date
    @State private var durationMinutes: Double
    @State private var isAllDay: Bool
    @State private var selectedCalendar: String
    @State private var errorMessage: String?

    init(event: CalendarEvent, calendar: CalendarStore, close: @escaping () -> Void) {
        self.event = event
        self.calendar = calendar
        self.close = close
        let systemCalendar = Calendar.current
        _title = State(initialValue: event.title)
        _date = State(initialValue: systemCalendar.startOfDay(for: event.startDate))
        _time = State(initialValue: event.startDate)
        _durationMinutes = State(initialValue: Self.sliderDuration(for: event))
        _isAllDay = State(initialValue: event.isAllDay)
        _selectedCalendar = State(initialValue: event.calendarName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("修改日程").font(.headline)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("收起修改面板")
            }

            fieldRow("标题") {
                TextField("日程标题", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            fieldRow("日期") {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            fieldRow("时间") {
                DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .disabled(isAllDay)
            }
            fieldRow("分类") {
                Picker("项目分类", selection: $selectedCalendar) {
                    ForEach(calendarOptions, id: \.self) { title in
                        Text(title).tag(title)
                    }
                }
                .labelsHidden()
            }
            Toggle("全天", isOn: $isAllDay)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("持续时间")
                    Spacer()
                    Text(isAllDay ? "全天" : durationText)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $durationMinutes, in: 0...240, step: 30)
                    .disabled(isAllDay)
                HStack {
                    Text("时间点").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("4小时").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack { Spacer(); Button("保存", action: save).keyboardShortcut(.defaultAction) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label).frame(width: 32, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private var calendarOptions: [String] {
        let names = calendar.iCloudCalendarNames
        return names.contains(selectedCalendar) ? names : [selectedCalendar] + names
    }

    private var durationText: String {
        let minutes = Int(durationMinutes)
        if minutes == 0 { return "时间点" }
        if minutes < 60 { return "\(minutes)分钟" }
        return minutes % 60 == 0 ? "\(minutes / 60)小时" : "\(minutes / 60)小时\(minutes % 60)分钟"
    }

    private func save() {
        let systemCalendar = Calendar.current
        let start: Date
        let end: Date
        if isAllDay {
            start = systemCalendar.startOfDay(for: date)
            end = systemCalendar.date(byAdding: .day, value: 1, to: start) ?? start
        } else {
            var components = systemCalendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = systemCalendar.dateComponents([.hour, .minute], from: time)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            start = systemCalendar.date(from: components) ?? date
            end = start.addingTimeInterval(durationMinutes * 60)
        }

        do {
            try calendar.update(
                event,
                title: title,
                startDate: start,
                endDate: end,
                calendarTitle: selectedCalendar,
                isAllDay: isAllDay
            )
            close()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func sliderDuration(for event: CalendarEvent) -> Double {
        guard !event.isAllDay else { return 60 }
        let rawMinutes = max(0, event.endDate.timeIntervalSince(event.startDate) / 60)
        return min(240, (rawMinutes / 30).rounded() * 30)
    }
}
