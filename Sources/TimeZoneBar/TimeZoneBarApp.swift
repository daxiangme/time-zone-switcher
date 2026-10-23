import AppKit
import SwiftUI

@main
struct TimeZoneBarApp: App {
    @StateObject private var viewModel = TimeZoneBarViewModel()

    var body: some Scene {
        MenuBarExtra {
            ControlPanelView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window(viewModel.localized("Settings"), id: "settings") {
            SettingsView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 680)
        .defaultLaunchBehavior(.suppressed)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var viewModel: TimeZoneBarViewModel

    var body: some View {
        if let timeText = viewModel.menuBarTimeText {
            Text(timeText)
                .font(.system(.body, design: .rounded).monospacedDigit())
        } else {
            Image(systemName: viewModel.menuBarIconName)
        }
    }
}
