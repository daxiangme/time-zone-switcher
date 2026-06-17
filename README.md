# Time Zone Switcher

[![CI](https://github.com/daxiangme/time-zone-switcher/actions/workflows/ci.yml/badge.svg)](https://github.com/daxiangme/time-zone-switcher/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/daxiangme/time-zone-switcher?display_name=tag)](https://github.com/daxiangme/time-zone-switcher/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-111827)
![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-f05138)

[中文说明](README.zh-CN.md)

A macOS menu bar app for temporarily switching the system time zone and restoring it later.

Use it when you need to test calendar, schedule, subscription, localization, or region-sensitive behavior without permanently changing your normal system setup.

[Download the latest release](https://github.com/daxiangme/time-zone-switcher/releases/latest)

![Time Zone Switcher preview](docs/assets/preview.svg)

## Why It Exists

Developers, QA engineers, product builders, and support teams often need to answer questions like:

- Does this calendar event render correctly in Pacific Time?
- Does a scheduled workflow cross midnight in another region?
- Does a subscription, billing period, or date boundary behave correctly outside my local time zone?
- Can I reproduce a customer issue that only appears in another time zone?

Time Zone Switcher makes that workflow fast and reversible from the menu bar.

## Features

- Menu bar only: no Dock icon.
- Search and select any IANA time zone, such as `America/Los_Angeles`, `Europe/London`, or `Asia/Tokyo`.
- Localized time zone display names with the IANA identifier kept visible.
- Toggle on to record the current system time zone and switch to the selected target.
- Toggle off to restore the recorded original time zone.
- Native SwiftUI controls and macOS material styling.

## Privacy and Security

- No analytics.
- No network requests.
- No background polling jobs.
- Administrator permission is requested only when you toggle the override on or off.
- The system command used is:

```bash
systemsetup -settimezone <IANA time zone identifier>
```

## Installation

Download the latest release archive, unzip it, and move `Time Zone Switcher.app` to `/Applications`.

This project currently publishes unsigned, non-notarized open-source builds. On first launch, macOS may block the app because it was downloaded from the internet. To open it:

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Find the blocked app message and choose **Open Anyway**.

You can also Control-click the app and choose **Open**.

## Build From Source

Requirements:

- macOS 26+
- Xcode 26+
- Swift 6.3+

Build the app bundle:

```bash
Scripts/build_app.sh
```

Run it:

```bash
open "dist/Time Zone Switcher.app"
```

Create a release archive:

```bash
Scripts/package_release.sh
```

## Roadmap

- Favorite time zones.
- Menu bar compact status.
- Keyboard shortcuts.
- Optional DMG packaging.
- Optional notarized builds.
- More localization.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
