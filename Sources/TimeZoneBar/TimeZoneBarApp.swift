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

        Settings {
            SettingsView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var viewModel: TimeZoneBarViewModel

    var body: some View {
        HStack(spacing: 4) {
            if viewModel.menuBarShowsIcon {
                Image(systemName: viewModel.menuBarIconName)
            }
            if let timeText = viewModel.menuBarTimeText {
                Text(timeText)
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }
        }
    }
}
