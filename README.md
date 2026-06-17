# Time Zone Switcher

[中文说明](README.zh-CN.md)

Time Zone Switcher is a lightweight macOS 26+ menu bar app for temporarily switching the system time zone and restoring it later.

It is designed for people who need to test products, schedules, calendars, subscriptions, or region-sensitive workflows under another time zone without permanently changing their normal system setup.

## Features

- Lives in the macOS menu bar without a Dock icon.
- Search and select any IANA time zone, such as `America/Los_Angeles`, `Europe/London`, or `Asia/Tokyo`.
- Shows localized time zone names while keeping the IANA identifier visible.
- Toggle on to record the current system time zone and switch to the selected target.
- Toggle off to restore the recorded original time zone.
- Persists the selected target time zone and restore state with `UserDefaults`.
- Uses native SwiftUI controls and macOS material styling.

## Installation

Download the latest release archive from GitHub Releases, unzip it, and move `Time Zone Switcher.app` to `/Applications`.

The release build is currently not notarized. On first launch, macOS may block it because it was downloaded from the internet. To open it:

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Find the blocked app message and choose **Open Anyway**.

You can also Control-click the app and choose **Open**.

## Why Administrator Permission Is Required

macOS requires administrator authorization to change the system time zone. Time Zone Switcher asks for administrator permission only when you toggle the override on or off.

The app uses:

```bash
systemsetup -settimezone <IANA time zone identifier>
```

The app does not collect data, does not send network requests, and does not run hidden polling jobs.

## Build From Source

Requirements:

- macOS 26+
- Xcode 26+
- Swift 6.3+

Build the app bundle:

```bash
Scripts/build_app.sh
```

The local app bundle is created at:

```text
dist/Time Zone Switcher.app
```

Run it:

```bash
open "dist/Time Zone Switcher.app"
```

Create a release archive:

```bash
Scripts/package_release.sh
```

The script creates a zip archive and SHA256 checksum under `dist/releases`.

## Development

Run tests:

```bash
swift test
```

Build without packaging:

```bash
swift build -c release --product TimeZoneBar
```

## License

MIT
