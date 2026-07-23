import SwiftUI

struct DashboardView: View {
    @ObservedObject var calendar: CalendarStore
    @ObservedObject var google: GoogleCalendarClient
    @State private var input = ""
    @State private var feedback = ""
    @State private var selectedCalendar = ""
    @State private var durationMinutes = 60.0
    @State private var isAllDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("NextCountdown").font(.largeTitle).bold()

            if let event = calendar.nextEvent {
                VStack(alignment: .leading, spacing: 6) {
                    Text("下一场日程").font(.caption).foregroundStyle(.secondary)
                    Text(event.title).font(.title2).bold()
                    Text(event.startDate, format: .dateTime.weekday(.wide).hour().minute())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView("还没有下一场日程", systemImage: "calendar.badge.clock", description: Text("请先允许日历权限，或在下面添加一个日程。"))
                    .frame(maxWidth: .infinity)
            }

            TextField("例如：明天下午4点在tamagawa开会", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            HStack {
                Picker("日历", selection: $selectedCalendar) {
                    Text("日历").tag("")
                    ForEach(calendar.iCloudCalendarNames.filter { $0 != "日历" }, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("持续时间")
                    Spacer()
                    Text(isAllDay ? "全天" : durationText)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $durationMinutes, in: 0...240, step: 30)
                    .disabled(isAllDay)
                HStack {
                    Text("时间点").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("4小时").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("全天", isOn: $isAllDay)
            }
            HStack {
                Button("添加到日历", action: add).disabled(input.isEmpty)
                Button("请求日历权限") { Task { await calendar.requestAccessAndRefresh() } }
                Spacer()
                Text(feedback).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("日常使用时，直接点击菜单栏的日历倒计时即可。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func add() {
        do {
            let event = try NaturalLanguageParser.parse(isAllDay ? "\(input) 全天" : input)
            var configuredEvent = event
            configuredEvent.calendarTitle = selectedCalendar.isEmpty ? nil : selectedCalendar
            applyDuration(to: &configuredEvent)
            try calendar.create(configuredEvent)
            input = ""
            feedback = "已添加"
        } catch {
            feedback = error.localizedDescription
        }
    }

    private var durationText: String {
        let minutes = Int(durationMinutes)
        if minutes == 0 { return "时间点" }
        if minutes < 60 { return "\(minutes)分钟" }
        return minutes % 60 == 0 ? "\(minutes / 60)小时" : "\(minutes / 60)小时\(minutes % 60)分钟"
    }

    private func applyDuration(to event: inout NewEvent) {
        event.isAllDay = isAllDay
        let calendar = Calendar.current
        if isAllDay {
            event.startDate = calendar.startOfDay(for: event.startDate)
            event.endDate = calendar.date(byAdding: .day, value: 1, to: event.startDate)!
        } else if durationMinutes == 0 {
            event.endDate = event.startDate
        } else {
            event.endDate = calendar.date(byAdding: .minute, value: Int(durationMinutes), to: event.startDate)!
        }
    }
}
