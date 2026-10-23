import AppKit
import SwiftUI
import TimeZoneCore

struct ControlPanelView: View {
    static let width: CGFloat = 380
    private static let maxVisibleRows = 8
    private static let rowSpacing: CGFloat = 2
    private static let listPadding: CGFloat = 6

    @ObservedObject var viewModel: TimeZoneBarViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var isAdding = false
    @State private var renamingIdentifier: String?

    var body: some View {
        VStack(spacing: 0) {
            if isAdding {
                AddTimeZoneView(viewModel: viewModel) {
                    isAdding = false
                }
                errorPanel
            } else {
                if viewModel.isEnabled {
                    overrideBanner
                }
                clockList
                errorPanel
                footer
            }
        }
        .frame(width: Self.width)
        .background(.regularMaterial)
        .animation(.snappy(duration: 0.2), value: viewModel.isEnabled)
        .animation(.snappy(duration: 0.2), value: isAdding)
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Override banner

    /// Only shown while the Mac runs on a borrowed time zone: says where it is and how to get back.
    private var overrideBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: viewModel.localized("System time zone changed to %@"), viewModel.systemDisplayName))
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let homeName = viewModel.homeDisplayName {
                    Text(String(format: viewModel.localized("Home time zone: %@"), homeName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button(viewModel.localized("Restore")) {
                viewModel.restore()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewModel.isWorking)
            .help(viewModel.localized("Restore Home Time Zone"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Clock list

    @ViewBuilder
    private var clockList: some View {
        let rows = viewModel.clockRows
        if rows.isEmpty {
            emptyState
        } else {
            List {
                ForEach(rows) { row in
                    ClockRowView(
                        row: row,
                        isRenaming: renamingIdentifier == row.identifier,
                        isDisabled: viewModel.isWorking,
                        localized: viewModel.localized
                    ) { action in
                        perform(action, on: row)
                    }
                    .listRowInsets(EdgeInsets(
                        top: Self.rowSpacing / 2,
                        leading: 6,
                        bottom: Self.rowSpacing / 2,
                        trailing: 6
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    viewModel.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, Self.listPadding, for: .scrollContent)
            .frame(height: listHeight(rowCount: rows.count))
        }
    }

    /// The popover grows with the list up to `maxVisibleRows`, then scrolls.
    private func listHeight(rowCount: Int) -> CGFloat {
        let visibleRows = CGFloat(min(rowCount, Self.maxVisibleRows))
        return visibleRows * (ClockRowView.height + Self.rowSpacing) + Self.listPadding * 2
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text(viewModel.localized("No saved time zones"))
                .font(.callout.weight(.medium))
            Text(viewModel.localized("Add time zones by searching"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    private func perform(_ action: ClockRowAction, on row: ClockRowModel) {
        switch action {
        case .setSystem:
            viewModel.apply(row.identifier)
        case .pin:
            viewModel.pin(row.identifier)
        case .beginRename:
            renamingIdentifier = row.identifier
        case .rename(let name):
            // Submitting also drops focus, which reports the same name again; only the first counts.
            guard renamingIdentifier == row.identifier else { return }
            renamingIdentifier = nil
            viewModel.setCustomLabel(name, for: row.identifier)
        case .cancelRename:
            renamingIdentifier = nil
        case .remove:
            viewModel.remove(row.identifier)
        }
    }

    // MARK: - Error and footer

    @ViewBuilder
    private var errorPanel: some View {
        if let message = viewModel.errorMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Button {
                viewModel.errorMessage = nil
                isAdding = true
            } label: {
                Label(viewModel.localized("Add Time Zone"), systemImage: "plus")
            }
            .buttonStyle(FooterButtonStyle())

            Spacer(minLength: 0)

            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(FooterButtonStyle())
            .help(viewModel.localized("Settings"))

            Button {
                viewModel.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(FooterButtonStyle())
            .help(viewModel.localized("Quit"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FooterButton(configuration: configuration)
    }

    private struct FooterButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.callout)
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .background(
                    Color.primary.opacity(configuration.isPressed ? 0.12 : isHovering ? 0.06 : 0),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .onHover { isHovering = $0 }
        }
    }
}
