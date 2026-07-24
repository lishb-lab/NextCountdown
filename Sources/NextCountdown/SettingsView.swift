import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var calendar: CalendarStore
    @ObservedObject var google: GoogleCalendarClient
    @State private var localModelStatus = LocalEventIntelligence.availabilityText()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NextCountdown 设置").font(.title2).bold()
            GroupBox("Apple 日历") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本应用通过 macOS 日历读取和创建日程。")
                    Button("重新请求权限") { Task { await calendar.requestAccessAndRefresh() } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("本地智能") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localModelStatus)
                    Text("可用时会用 Apple 智能在本机提取事件、地点、时间和状态栏两字摘要；不可用时自动使用本地规则。")
                        .fixedSize(horizontal: false, vertical: true)
                    Button("重新检查") { localModelStatus = LocalEventIntelligence.availabilityText() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Google 日历") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最简单的连接方式：在 macOS“系统设置 → 互联网账户”添加 Google 账户，并启用“日历”。Google 日历会作为普通日历出现在本应用中；新增日程会同步回 Google。")
                        .fixedSize(horizontal: false, vertical: true)
                    Link("打开 macOS 互联网账户设置", destination: URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!)
                    Divider()
                    Text("直接 Google OAuth（可选）") .font(.headline)
                    Text("若要绕开系统账户，可配置自己的 Google OAuth Client ID；此 MVP 已保留入口，完整 OAuth 令牌交换将在下一步接入。")
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Google OAuth Client ID", text: $google.clientID)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
            HStack { Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(22)
        .frame(width: 520, height: 440)
    }
}
