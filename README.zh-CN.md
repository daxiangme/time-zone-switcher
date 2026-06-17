# 时区切换器

[English](README.md)

时区切换器是一个 macOS 26+ 菜单栏小工具，用于临时切换系统时区，并在需要时恢复到之前记录的时区。

它适合用于测试产品、日程、日历、订阅、区域相关逻辑，或者临时让系统进入另一个时区，而不需要永久改变自己的日常系统设置。

## 功能

- 常驻 macOS 菜单栏，不显示 Dock 图标。
- 支持搜索和选择任意 IANA 时区，例如 `America/Los_Angeles`、`Europe/London`、`Asia/Tokyo`。
- 时区名称跟随 macOS 系统语言本地化显示，同时保留 IANA 标识，避免歧义。
- 打开开关时，记录当前系统时区，然后切换到所选目标时区。
- 关闭开关时，恢复到之前记录的系统时区。
- 使用 `UserDefaults` 保存目标时区和恢复状态。
- 使用原生 SwiftUI 控件和 macOS 材质风格。

## 安装

从 GitHub Releases 下载最新压缩包，解压后把 `Time Zone Switcher.app` 拖到 `/Applications`。

当前发布包没有做 Apple notarization。首次打开时，macOS 可能会因为它来自互联网而阻止启动。可以这样打开：

1. 打开 **系统设置**。
2. 进入 **隐私与安全性**。
3. 找到被阻止的 App 提示，选择 **仍要打开**。

也可以按住 Control 点击 App，然后选择 **打开**。

## 为什么需要管理员权限

macOS 修改系统时区需要管理员授权。时区切换器只会在你打开或关闭时区切换开关时请求管理员权限。

底层使用的命令是：

```bash
systemsetup -settimezone <IANA 时区标识>
```

这个 App 不收集数据，不发送网络请求，也不会在后台做隐藏轮询。

## 从源码构建

环境要求：

- macOS 26+
- Xcode 26+
- Swift 6.3+

构建 App：

```bash
Scripts/build_app.sh
```

本地 App 会生成到：

```text
dist/Time Zone Switcher.app
```

运行：

```bash
open "dist/Time Zone Switcher.app"
```

生成发布压缩包：

```bash
Scripts/package_release.sh
```

脚本会在 `dist/releases` 下生成 zip 压缩包和 SHA256 校验文件。

## 开发

运行测试：

```bash
swift test
```

只构建 release 二进制：

```bash
swift build -c release --product TimeZoneBar
```

## 许可证

MIT
