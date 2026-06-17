import SwiftUI
import TimeZoneCore

struct ControlPanelView: View {
    @ObservedObject var viewModel: TimeZoneBarViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 14) {
                statusPanel
                targetPanel
                errorPanel
            }
            .padding(16)

            Spacer(minLength: 0)

            footer
        }
        .background(.regularMaterial)
        .onAppear {
            viewModel.refreshCurrentTimeZone()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(viewModel.isEnabled ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: viewModel.isEnabled ? "clock.badge.checkmark" : "clock")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(viewModel.isEnabled ? Color.accentColor : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("Time Zone"))
                    .font(.headline)

                Text(L10n.string(viewModel.isEnabled ? "Override active" : "System time"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { viewModel.setEnabled($0) }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(viewModel.isWorking)
            .help(L10n.string(viewModel.isEnabled ? "Restore previous time zone" : "Switch to selected time zone"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var statusPanel: some View {
        VStack(spacing: 10) {
            InfoRow(
                label: L10n.string("Current"),
                title: viewModel.displayName(for: viewModel.currentIdentifier),
                subtitle: viewModel.currentIdentifier,
                systemImage: "location"
            )
            InfoRow(
                label: L10n.string("Target"),
                title: viewModel.displayName(for: viewModel.targetIdentifier),
                subtitle: viewModel.targetIdentifier,
                systemImage: "scope"
            )

            if let originalIdentifier = viewModel.originalIdentifier {
                InfoRow(
                    label: L10n.string("Restore"),
                    title: viewModel.displayName(for: originalIdentifier),
                    subtitle: originalIdentifier,
                    systemImage: "arrow.uturn.backward"
                )
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var targetPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L10n.string("Search time zones"), text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredEntries, id: \.identifier) { entry in
                        TimeZoneRow(
                            entry: entry,
                            isSelected: entry.identifier == viewModel.targetIdentifier,
                            isDisabled: viewModel.isWorking
                        ) {
                            viewModel.selectTarget(entry.identifier)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 260)
        }
    }

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
        }
    }

    private var footer: some View {
        HStack {
            Button {
                viewModel.refreshCurrentTimeZone()
            } label: {
                Label(L10n.string("Refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isWorking)
            .buttonStyle(FooterButtonStyle())

            Spacer()

            Button {
                viewModel.quit()
            } label: {
                Label(L10n.string("Quit"), systemImage: "power")
            }
            .buttonStyle(FooterButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 34, alignment: .center)
        .padding(.top, 9)
        .padding(.bottom, 17)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct InfoRow: View {
    let label: String
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 2)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TimeZoneRow: View {
    let entry: TimeZoneCatalogEntry
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.55))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.displayName())
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(entry.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundStyle(configuration.isPressed ? Color.accentColor : Color.secondary)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .frame(height: 32, alignment: .center)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background(
                configuration.isPressed ? Color.secondary.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
    }
}

private enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
