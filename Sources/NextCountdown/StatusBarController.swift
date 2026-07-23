import AppKit
import Combine
import SwiftUI

/// AppKit's NSStatusItem is used instead of MenuBarExtra because it reliably
/// attaches to the macOS menu bar even when the app is launched from a package.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let calendar: CalendarStore
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var globalMouseMonitor: Any?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    init(calendar: CalendarStore, google: GoogleCalendarClient) {
        self.calendar = calendar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuContent(calendar: calendar, google: google)
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "NextCountdown")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }

        calendar.$nextEvent
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }
            .store(in: &cancellables)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateLabel() }
        }
        updateLabel()
    }

    deinit {
        timer?.invalidate()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            startClickMonitoring()
        }
    }

    /// Transient popovers normally close by themselves. The global monitor
    /// also handles menu-bar controls (such as Control Center) consistently.
    private func startClickMonitoring() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.closeIfClickOutsidePopover() }
        }
    }

    private func closeIfClickOutsidePopover() {
        guard popover.isShown,
              let window = popover.contentViewController?.view.window else { return }
        // A status-bar app can receive its own panel clicks through the global
        // monitor. Only dismiss after a click outside the popover's screen frame.
        if !window.frame.contains(NSEvent.mouseLocation) {
            popover.performClose(nil)
        }
    }

    private func stopClickMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopClickMonitoring()
    }

    private func updateLabel() {
        guard let button = statusItem.button else { return }
        guard let event = calendar.nextEvent else {
            button.title = " 无日程"
            return
        }
        let remaining = event.startDate.timeIntervalSinceNow
        guard remaining > 0 else {
            calendar.refresh()
            return
        }
        button.title = " \(shortDescription(for: event.title)) · \(dateFormatter.string(from: event.startDate)) · \(countdown(remaining))"
    }

    private func shortDescription(for title: String) -> String {
        let plainTitle = title.components(separatedBy: "@").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? title
        let deadlineWords = ["提交", "材料", "截止", "ddl"]
        if deadlineWords.contains(where: { plainTitle.localizedCaseInsensitiveContains($0) }) { return "ddl" }
        let actionKeywords = ["面试", "开会", "会议", "讨论", "汇报", "见面", "会谈", "拜访", "吃饭", "上课", "就诊"]
        if let action = actionKeywords.first(where: { plainTitle.contains($0) }) {
            return action == "会议" ? "开会" : action
        }
        return plainTitle.count > 8 ? String(plainTitle.prefix(8)) + "…" : plainTitle
    }

    private func countdown(_ remaining: TimeInterval) -> String {
        let minutes = max(1, Int(remaining / 60))
        if minutes >= 1_440 { return "\(minutes / 1_440)d" }
        if minutes >= 60 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }
}
