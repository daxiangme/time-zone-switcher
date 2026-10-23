import AppKit
import SwiftUI
import TimeZoneCore

struct ControlPanelView: View {
    static let width: CGFloat = 380
    private static let maxVisibleRows = 8
    private static let rowSpacing: CGFloat = 2
    private static let listPadding: CGFloat = 6

    @ObservedObject var viewModel: TimeZoneBarViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var isAdding = false
    @State private var renamingIdentifier: String?

    var body: some View {
        VStack(spacing: 0) {
            if isAdding {
                VStack(spacing: 0) {
                    AddTimeZoneView(viewModel: viewModel) {
                        isAdding = false
                    }
                    errorPanel
                }
                .transition(.push(from: .trailing))
            } else {
                VStack(spacing: 0) {
                    if viewModel.isEnabled {
                        overrideBanner
                    }
                    clockList
                    errorPanel
                    footer
                }
                .transition(.push(from: .leading))
            }
        }
        .frame(width: Self.width)
        .clipped()
        .background(.regularMaterial)
        .animation(.snappy(duration: 0.3), value: viewModel.isEnabled)
        .animation(.snappy(duration: 0.3), value: isAdding)
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

            Button {
                viewModel.restore()
            } label: {
                if isRestoring {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text(viewModel.localized("Restore"))
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(viewModel.isWorking)
            .help(viewModel.localized("Restore Home Time Zone"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var isRestoring: Bool {
        viewModel.isWorking && viewModel.switchingIdentifier != nil
            && viewModel.switchingIdentifier == viewModel.homeIdentifier
    }

    // MARK: - Clock list

    @ViewBuilder
    private var clockList: some View {
        let rows = viewModel.clockRows
        if rows.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List {
                    ForEach(rows) { row in
                        ClockRowView(
                            row: row,
                            isRenaming: renamingIdentifier == row.identifier,
                            isDisabled: viewModel.isWorking,
                            isSwitching: viewModel.switchingIdentifier == row.identifier,
                            isHighlighted: viewModel.recentlyAddedIdentifier == row.identifier,
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
                .animation(.snappy(duration: 0.3), value: rows.map(\.identifier))
                .onAppear {
                    // Coming back from the add picker: bring the new row into view.
                    if let added = viewModel.recentlyAddedIdentifier {
                        proxy.scrollTo(added)
                    }
                }
            }
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
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    viewModel.errorMessage = nil
                    isAdding = true
                } label: {
                    Label(viewModel.localized("Add Time Zone"), systemImage: "plus")
                }
                .buttonStyle(.glass)

                Spacer(minLength: 0)

                Button {
                    openSettings()
                    // A menu bar–only app isn't active, so the settings window would open behind others.
                    NSApp.activate()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(viewModel.localized("Settings"))

                Button {
                    viewModel.quit()
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(viewModel.localized("Quit"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}
