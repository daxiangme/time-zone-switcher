import SwiftUI

@main
struct TimeZoneBarApp: App {
    @StateObject private var viewModel = TimeZoneBarViewModel()

    var body: some Scene {
        MenuBarExtra {
            ControlPanelView(viewModel: viewModel)
                .frame(width: 380, height: 520)
        } label: {
            Image(systemName: viewModel.isEnabled ? "clock.badge.checkmark" : "clock")
        }
        .menuBarExtraStyle(.window)
    }
}
