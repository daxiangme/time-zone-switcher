import AppKit
import SwiftUI
import TimeZoneCore

// Renders the popover and the settings window offscreen with fake state, so UI changes
// can be compared without touching the real system time zone or UserDefaults.

private final class FakeSystemTimeZoneService: SystemTimeZoneServicing {
    private var identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }

    func currentTimeZoneIdentifier() throws -> String { identifier }
    func setTimeZone(identifier: String) throws { self.identifier = identifier }
}

private struct Scenario {
    let name: String
    let systemIdentifier: String
    let store: (AppLanguage) -> InMemoryTimeZoneStore
}

private let savedIdentifiers = [
    "Asia/Shanghai",
    "America/Los_Angeles",
    "Europe/London",
    "Asia/Tokyo",
    "America/New_York"
]

private let scenarios = [
    Scenario(name: "override", systemIdentifier: "America/Los_Angeles") { language in
        InMemoryTimeZoneStore(
            savedIdentifiers: savedIdentifiers,
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true,
            menuBarMode: .pinned("Asia/Shanghai"),
            appLanguage: language,
            customLabels: ["Asia/Shanghai": language == .english ? "Home" : "家里"]
        )
    },
    Scenario(name: "normal", systemIdentifier: "Asia/Shanghai") { language in
        InMemoryTimeZoneStore(savedIdentifiers: savedIdentifiers, appLanguage: language)
    },
    Scenario(name: "empty", systemIdentifier: "Asia/Shanghai") { language in
        InMemoryTimeZoneStore(appLanguage: language)
    }
]

private let languages: [(String, AppLanguage)] = [("zh", .simplifiedChinese), ("en", .english)]
private let appearances: [(String, NSAppearance.Name)] = [("dark", .darkAqua), ("light", .aqua)]

@MainActor
/// A nil height sizes the window to the view, like the menu bar popover does.
private func render<V: View>(_ view: V, width: CGFloat, height: CGFloat? = nil, appearance: NSAppearance.Name, to url: URL) throws {
    let window = NSWindow(
        contentRect: CGRect(origin: CGPoint(x: -10_000, y: -10_000), size: CGSize(width: width, height: height ?? 600)),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: appearance)
    let host = NSHostingView(
        rootView: view
            .frame(width: width, height: height)
            .background(Color(nsColor: .windowBackgroundColor))
    )
    window.contentView = host
    let size = CGSize(width: width, height: height ?? host.fittingSize.height)
    window.setContentSize(size)
    host.frame = CGRect(origin: .zero, size: size)
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    host.layoutSubtreeIfNeeded()

    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
        throw CocoaError(.fileWriteUnknown)
    }
    host.cacheDisplay(in: host.bounds, to: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
    window.orderOut(nil)
}

MainActor.assumeIsolated {
    NSApplication.shared.setActivationPolicy(.prohibited)

    let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "snapshots", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (languageCode, language) in languages {
            for (appearanceName, appearance) in appearances {
                for scenario in scenarios {
                    let viewModel = TimeZoneBarViewModel(
                        store: scenario.store(language),
                        system: FakeSystemTimeZoneService(identifier: scenario.systemIdentifier)
                    )
                    let file = output.appendingPathComponent("panel-\(scenario.name)-\(languageCode)-\(appearanceName).png")
                    try render(
                        ControlPanelView(viewModel: viewModel),
                        width: ControlPanelView.width,
                        appearance: appearance,
                        to: file
                    )
                    print(file.path)
                }

                let pickerModel = TimeZoneBarViewModel(
                    store: scenarios[0].store(language),
                    system: FakeSystemTimeZoneService(identifier: scenarios[0].systemIdentifier)
                )
                let pickerFile = output.appendingPathComponent("add-\(languageCode)-\(appearanceName).png")
                try render(
                    AddTimeZoneView(viewModel: pickerModel) {},
                    width: ControlPanelView.width,
                    appearance: appearance,
                    to: pickerFile
                )
                print(pickerFile.path)

                let viewModel = TimeZoneBarViewModel(
                    store: scenarios[0].store(language),
                    system: FakeSystemTimeZoneService(identifier: scenarios[0].systemIdentifier)
                )
                let file = output.appendingPathComponent("settings-\(languageCode)-\(appearanceName).png")
                try render(
                    SettingsView(viewModel: viewModel),
                    width: SettingsView.width,
                    appearance: appearance,
                    to: file
                )
                print(file.path)
            }
        }
    } catch {
        FileHandle.standardError.write(Data("snapshot failed: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}
