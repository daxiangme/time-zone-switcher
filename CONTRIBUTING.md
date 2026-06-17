# Contributing

Thanks for your interest in Time Zone Switcher.

## Development Setup

Requirements:

- macOS 26+
- Xcode 26+
- Swift 6.3+

Run tests:

```bash
swift test
```

Build the app bundle:

```bash
Scripts/build_app.sh
```

Create a release archive:

```bash
Scripts/package_release.sh
```

## Project Principles

- Keep the app lightweight and menu-bar first.
- Keep the switching behavior explicit and reversible.
- Do not add analytics, telemetry, network calls, or hidden polling without prior discussion.
- Keep IANA time zone identifiers visible even when display names are localized.
- Prefer native SwiftUI/macOS controls over custom UI where possible.

## Pull Requests

Before opening a pull request:

- Run `swift test`.
- Include a concise explanation of the user-facing change.
- Include screenshots or screen recordings for UI changes.
- Update README content when behavior or installation changes.

## 中文说明

欢迎参与时区切换器。

开发前请确认环境：

- macOS 26+
- Xcode 26+
- Swift 6.3+

运行测试：

```bash
swift test
```

构建 App：

```bash
Scripts/build_app.sh
```

项目原则：

- 保持轻量，优先服务菜单栏使用场景。
- 时区切换必须明确、可恢复。
- 不添加分析、遥测、网络请求或隐藏轮询，除非先充分讨论。
- 即使显示本地化名称，也要保留 IANA 时区标识。
- 优先使用原生 SwiftUI/macOS 控件。
