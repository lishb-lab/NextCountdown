import AppKit
import SwiftUI

struct MenuContent: View {
    @ObservedObject var calendar: CalendarStore
    @ObservedObject var google: GoogleCalendarClient
    @State private var input = ""
    @State private var resultMessage: String?
    @State private var showingSettings = false
    @State private var selectedCalendar = ""
    @State private var durationMinutes = 60.0
    @State private var isAllDay = false
    @State private var localModelStatus = LocalEventIntelligence.availabilityText()

    var body: some View {
        Group {
            if showingSettings {
                settingsPanel
            } else {
                mainPanel
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            quickAdd
            Divider()
            events
            Divider()
            HStack {
                Button("刷新") { calendar.refresh() }
                Spacer()
                Button("设置") { showingSettings = true }
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置").font(.headline)
            GroupBox("日历") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本应用通过 macOS 日历读取和创建日程。")
                    Button("重新请求日历权限") { Task { await calendar.requestAccessAndRefresh() } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("本地智能") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localModelStatus)
                    Text("可用时在本机理解短句；不可用时自动使用规则解析。")
                        .fixedSize(horizontal: false, vertical: true)
                    Button("重新检查") { localModelStatus = LocalEventIntelligence.availabilityText() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("完成") { showingSettings = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var header: some View {
        Group {
            if let event = calendar.nextEvent {
                if let current = calendar.currentEvent {
                    eventHeader(current, label: "当前进行中")
                } else {
                    eventHeader(event, label: "下一个日程")
                }
            } else if let current = calendar.currentEvent {
                eventHeader(current, label: "当前进行中")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("没有即将开始的日程").font(.headline)
                    Text("添加一个待办，倒计时会自动出现。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func eventHeader(_ event: CalendarEvent, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(event.title).font(.headline).lineLimit(1)
            HStack(spacing: 5) {
                Text(event.startDate, format: .dateTime.hour().minute())
                Text("–")
                Text(event.endDate, format: .dateTime.hour().minute())
                Text("·")
                Text(event.calendarName)
            }
            .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用自然语言添加").font(.caption).foregroundStyle(.secondary)
            TextField("例如：明天下午4点在tamagawa开会", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addFromText)
            Picker("日历", selection: $selectedCalendar) {
                Text("日历").tag("")
                ForEach(calendar.iCloudCalendarNames.filter { $0 != "日历" }, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("持续时间").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(isAllDay ? "全天" : durationText).font(.caption).foregroundStyle(.secondary)
                }
                Slider(value: $durationMinutes, in: 0...240, step: 30)
                    .disabled(isAllDay)
                HStack {
                    Text("时间点").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("4小时").font(.caption2).foregroundStyle(.secondary)
                }
                Toggle("全天", isOn: $isAllDay)
                    .controlSize(.small)
            }
            HStack {
                Button("添加到日历", action: addFromText)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let resultMessage {
                    Text(resultMessage).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private var events: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("接下来").font(.caption).foregroundStyle(.secondary)
            if calendar.upcomingEvents.isEmpty {
                accessStateView
            } else {
                ForEach(calendar.upcomingEvents.prefix(4)) { event in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title).lineLimit(1)
                            Text(event.calendarName).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.startDate, format: .dateTime.weekday(.abbreviated).hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            delete(event)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("删除此事件")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accessStateView: some View {
        switch calendar.accessState {
        case .unknown:
            Text("正在请求日历权限…").foregroundStyle(.secondary)
        case .denied:
            Text("请在“系统设置 → 隐私与安全性 → 日历”中允许访问。").foregroundStyle(.secondary)
        case .error(let message):
            Text(message).foregroundStyle(.red)
        case .granted:
            Text("未来 90 天没有非全天日程。") .foregroundStyle(.secondary)
        }
    }

    private func addFromText() {
        let command = isAllDay ? "\(input) 全天" : input
        Task { @MainActor in
            do {
                var event = try await NaturalLanguageParser.parsePreferred(command)
                event.calendarTitle = selectedCalendar.isEmpty ? nil : selectedCalendar
                applyDuration(to: &event)
                try calendar.create(event)
                input = ""
                resultMessage = "已添加：\(event.title)"
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ event: CalendarEvent) {
        do {
            try calendar.delete(event)
            resultMessage = "已删除：\(event.title)"
        } catch {
            resultMessage = error.localizedDescription
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
