import AppKit
import SwiftUI
import TimeZoneCore

struct ControlPanelView: View {
    @ObservedObject var viewModel: TimeZoneBarViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var isAdding = false
    @State private var renameIdentifier: String?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            clockList
                .frame(maxHeight: .infinity)
            if isAdding {
                searchPanel
            }
            errorPanel
            footer
        }
        .background(.regularMaterial)
        .onAppear {
            viewModel.refresh()
        }
        .alert(viewModel.localized("Rename"), isPresented: renamePresented) {
            TextField(viewModel.localized("Name"), text: $renameText)
            Button(viewModel.localized("Cancel"), role: .cancel) {}
            Button(viewModel.localized("Save")) {
                if let renameIdentifier {
                    viewModel.setCustomLabel(renameText, for: renameIdentifier)
                }
            }
        }
    }

    private var renamePresented: Binding<Bool> {
        Binding(
            get: { renameIdentifier != nil },
            set: { isPresented in
                if !isPresented {
                    renameIdentifier = nil
                }
            }
        )
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
                Text(viewModel.localized("Time Zone"))
                    .font(.headline)
                Text(viewModel.localized(viewModel.isEnabled ? "Override active" : "System time"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var clockList: some View {
        if viewModel.savedIdentifiers.isEmpty {
            VStack(spacing: 6) {
                Text(viewModel.localized("No saved time zones"))
                    .font(.callout)
                Text(viewModel.localized("Add time zones by searching"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        } else {
            List {
                ForEach(viewModel.savedIdentifiers, id: \.self) { identifier in
                    TimeZoneClockRow(
                        identifier: identifier,
                        title: viewModel.displayName(for: identifier),
                        face: viewModel.clockFace(for: identifier),
                        isSystem: identifier == viewModel.systemIdentifier,
                        isHome: viewModel.isEnabled && identifier == viewModel.homeIdentifier,
                        isPinned: pinnedIdentifier == identifier,
                        canDelete: viewModel.canRemove(identifier),
                        systemBadge: viewModel.localized("System"),
                        homeBadge: viewModel.localized("Home"),
                        isDisabled: viewModel.isWorking,
                        setSystemTitle: viewModel.localized("Set as System Time Zone"),
                        pinTitle: viewModel.localized("Show in Menu Bar"),
                        renameTitle: viewModel.localized("Rename"),
                        deleteTitle: viewModel.localized("Remove Time Zone"),
                        onApply: { viewModel.apply(identifier) },
                        onPin: { viewModel.pin(identifier) },
                        onRename: {
                            renameText = viewModel.displayName(for: identifier)
                            renameIdentifier = identifier
                        },
                        onDelete: { viewModel.remove(identifier) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    viewModel.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var pinnedIdentifier: String? {
        if case .pinned(let identifier) = viewModel.menuBarMode {
            return identifier
        }
        return nil
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(viewModel.localized("Search time zones"), text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            if !viewModel.filteredEntries.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.filteredEntries, id: \.identifier) { entry in
                            SearchResultRow(
                                title: entry.displayName(locale: viewModel.appLanguage.locale),
                                subtitle: viewModel.isSaved(entry.identifier)
                                    ? viewModel.localized("Already added")
                                    : entry.identifier,
                                isSaved: viewModel.isSaved(entry.identifier),
                                isDisabled: viewModel.isWorking
                            ) {
                                viewModel.add(entry.identifier)
                                isAdding = false
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 140)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button {
                isAdding.toggle()
                if !isAdding {
                    viewModel.searchText = ""
                }
            } label: {
                Label(viewModel.localized("Add"), systemImage: "plus")
            }
            .buttonStyle(FooterButtonStyle())

            if viewModel.isEnabled {
                Button {
                    viewModel.restore()
                } label: {
                    Label(viewModel.localized("Restore Home Time Zone"), systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.isWorking)
                .buttonStyle(FooterButtonStyle())
            }

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
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct TimeZoneClockRow: View {
    let identifier: String
    let title: String
    let face: TimeZoneClockFace?
    let isSystem: Bool
    let isHome: Bool
    let isPinned: Bool
    let canDelete: Bool
    let systemBadge: String
    let homeBadge: String
    let isDisabled: Bool
    let setSystemTitle: String
    let pinTitle: String
    let renameTitle: String
    let deleteTitle: String
    let onApply: () -> Void
    let onPin: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isSystem {
                        Badge(title: systemBadge)
                    }
                    if isHome {
                        Badge(title: homeBadge)
                    }
                }
                Text(identifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(face?.timeText ?? "—")
                }
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                if let dateText = face?.dateText {
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            rowMenu
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            isSystem ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .contextMenu {
            rowActions
        }
    }

    private var rowMenu: some View {
        Menu {
            rowActions
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var rowActions: some View {
        Button(setSystemTitle, action: onApply)
        Button(pinTitle, action: onPin)
        Button(renameTitle, action: onRename)
        Button(deleteTitle, action: onDelete)
            .disabled(!canDelete)
    }
}

private struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let isSaved: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSaved ? Color.secondary : Color.accentColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout)
                        .lineLimit(1)
                    Text(subtitle)
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
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isSaved)
    }
}

private struct Badge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
            .lineLimit(1)
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
