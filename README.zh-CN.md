<img src="docs/assets/icon.png" width="128" alt="时区切换器 App 图标">

# 时区切换器

[![CI](https://github.com/daxiangme/time-zone-switcher/actions/workflows/ci.yml/badge.svg)](https://github.com/daxiangme/time-zone-switcher/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/daxiangme/time-zone-switcher?display_name=tag)](https://github.com/daxiangme/time-zone-switcher/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-111827)
![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-f05138)

[English](README.md)

一个 macOS 菜单栏小工具，用于临时切换系统时区，并在需要时恢复到之前记录的时区。

当你需要测试日历、排期、订阅、国际化、区域相关逻辑时，可以用它快速切换时区，而不需要永久改变自己的日常系统设置。

[下载最新版本](https://github.com/daxiangme/time-zone-switcher/releases/latest)

<p align="center">
  <img src="docs/assets/screenshot-zh-Hans.png" width="380" alt="菜单栏弹出面板：已添加的时区和恢复横幅">
</p>

<p align="center">
  <img src="docs/assets/screenshot-add-zh-Hans.png" width="300" alt="添加时区选择器">
  <img src="docs/assets/screenshot-settings-en.png" width="300" alt="设置窗口">
</p>

## 为什么需要它

开发者、测试工程师、产品构建者和支持团队经常需要确认这些问题：

- 日历事件在太平洋时间下是否正确显示？
- 一个定时任务跨过其他地区的午夜时是否表现正常？
- 订阅、账期、日期边界在非本地时区是否正确？
- 能否复现只在某个时区出现的用户问题？

时区切换器把这个流程放到菜单栏里，并且可以随时恢复。

## 功能

- 只常驻菜单栏，不显示 Dock 图标。
- 可以添加多个 IANA 时区，例如 `America/Los_Angeles` 和 `Asia/Shanghai`，并同时看到每个时区的当地时间。
- 可以把任意已添加时区设为系统时区。第一次切走时会记住本机时区，恢复前不会覆盖这条记录。
- 菜单栏可以自动跟随当前系统时区、只显示图标，或固定显示某一个已添加时区的时间。
- 可以从预设里选时间格式，包括仅时间、缩写和时间、中文日期、英文日期，或自定义格式。可以选择是否显示秒。
- 界面语言可以跟随系统、使用简体中文或 English。语言不决定时钟的格式。
- 时区名称跟随系统语言本地化显示，同时保留 IANA 标识，避免歧义。
- 使用原生 SwiftUI 控件和 macOS 材质风格。

## 隐私与安全

- 不收集分析数据。
- 不发送网络请求。
- 不做后台轮询。
- 只会在你更改或恢复系统时区时请求管理员权限。
- 底层使用的系统命令是：

```bash
systemsetup -settimezone <IANA 时区标识>
```

## 安装

从最新 Release 下载压缩包，解压后把 `Time Zone Switcher.app` 拖到 `/Applications`。

当前发布包是开源项目常见的 unsigned、未 notarized 构建。首次打开时，macOS 可能会因为它来自互联网而阻止启动。可以这样打开：

1. 打开 **系统设置**。
2. 进入 **隐私与安全性**。
3. 找到被阻止的 App 提示，选择 **仍要打开**。

也可以按住 Control 点击 App，然后选择 **打开**。

## 从源码构建

环境要求：

- macOS 26+
- Xcode 26+
- Swift 6.3+

构建 App：

```bash
Scripts/build_app.sh
```

运行：

```bash
open "dist/Time Zone Switcher.app"
```

生成发布压缩包：

```bash
Scripts/package_release.sh
```

## 路线图

- 常用时区收藏。
- 快捷键。
- 可选 DMG 打包。
- 可选 notarized 构建。
- 更多语言本地化。

## 参与贡献

欢迎参与贡献。查看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

MIT
