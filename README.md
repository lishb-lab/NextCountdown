# NextCountdown

一个轻量 macOS 菜单栏应用：显示下一场日程倒计时，并可用中文自然语言快速创建 iCloud 日历事件。

## 功能

- 常驻菜单栏，不显示 Dock 图标；支持开机启动。
- 状态栏显示“事件缩略描述 · 月/日 · 倒计时”，例如 `面试 · 7/24 · 23h`。
- 当前有进行中的事件时，面板顶部优先显示“当前进行中”；状态栏仍倒计时下一场。
- 输入 `明天下午4点在tamagawa开会`，创建标题为 `开会@tamagawa`、地点为 `tamagawa` 的日程。
- 直接选择 iCloud 中真实的日历（如“日历、工作、个人、家庭”）。
- 持续时间支持时间点、30 分钟至 4 小时，以及全天。

## 运行

需要 macOS 14+ 和 Xcode：

```bash
cd NextCountdown
swift run
```

首次运行请允许访问“日历”。发布版需要作为 `.app` 包运行，并在 `Info.plist` 中声明 `NSCalendarsFullAccessUsageDescription`。

## 连接日历

- **Apple 日历/iCloud**：允许日历权限即可。
- **Google 日历**：在 **系统设置 → 互联网账户 → Google** 登录并启用“日历”。Google 日历会通过 macOS Calendar 同步；本项目默认创建 iCloud 日程。

## 自然语言示例

- `明天下午4点在tamagawa开会`（日历标题：`开会@tamagawa`）
- `周五下午3点 提交周报`
- `8月12日全天休假`

离线解析器当前覆盖中文常用日期、时间、全天和常见地点表达。
