import SwiftUI
import TimeZoneCore

enum ClockRowAction {
    case setSystem
    case pin
    case beginRename
    case rename(String)
    case cancelRename
    case remove
}

/// One saved time zone in the popover. The leading radio marks the Mac's current time zone
/// and switches to this one when clicked; the rest of the actions sit behind a hover menu.
struct ClockRowView: View {
    static let height: CGFloat = 50

    let row: ClockRowModel
    let isRenaming: Bool
    let isDisabled: Bool
    /// Waiting on the authorization prompt to switch the system time zone to (or back to) this row.
    let isSwitching: Bool
    /// Just added; tinted for a moment so it's easy to spot.
    let isHighlighted: Bool
    let localized: (String) -> String
    let onAction: (ClockRowAction) -> Void

    @State private var isHovering = false
    @State private var draftName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            systemRadio

            VStack(alignment: .leading, spacing: 2) {
                titleLine
                // The relative part stays whole; only the identifier gives way when space runs out.
                HStack(spacing: 0) {
                    Text((isSwitching ? localized("Switching…") : row.relativeText(localized: localized)) + " · ")
                        .layoutPriority(1)
                    Text(row.identifier)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: row.isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.caption)
                    .foregroundStyle(row.isDaytime ? Color.orange : Color.indigo)
                    .accessibilityHidden(true)
                Text(row.timeText)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }

            rowMenu
                .opacity(isHovering ? 1 : 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: Self.height)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .help(row.hasCustomLabel ? "\(row.cityName) · \(row.identifier)" : row.identifier)
        .contextMenu { rowActions }
    }

    private var rowBackground: Color {
        if isHighlighted {
            return Color.accentColor.opacity(0.18)
        }
        return isHovering ? Color.primary.opacity(0.06) : Color.clear
    }

    @ViewBuilder
    private var systemRadio: some View {
        if isSwitching {
            ProgressView()
                .controlSize(.small)
                .frame(width: 18, height: 18)
                .help(localized("Switching…"))
        } else {
            radioButton
        }
    }

    private var radioButton: some View {
        Button {
            onAction(.setSystem)
        } label: {
            Image(systemName: row.isSystem ? "largecircle.fill.circle" : "circle")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 15))
                .foregroundStyle(row.isSystem ? Color.accentColor : Color.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || row.isSystem)
        .help(row.isSystem ? localized("Current system time zone") : localized("Set as System Time Zone"))
    }

    @ViewBuilder
    private var titleLine: some View {
        if isRenaming {
            TextField(row.cityName, text: $draftName)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isNameFocused)
                .onAppear {
                    draftName = row.title
                    isNameFocused = true
                }
                .onSubmit { onAction(.rename(draftName)) }
                .onExitCommand { onAction(.cancelRename) }
                .onChange(of: isNameFocused) { _, focused in
                    if !focused {
                        onAction(.rename(draftName))
                    }
                }
        } else {
            HStack(spacing: 5) {
                Text(row.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) { onAction(.beginRename) }
                if row.isHome {
                    Badge(title: localized("Home"))
                }
                if row.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .help(localized("Show in Menu Bar"))
                }
            }
        }
    }

    private var rowMenu: some View {
        Menu {
            rowActions
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 22)
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var rowActions: some View {
        Button(localized("Set as System Time Zone")) { onAction(.setSystem) }
            .disabled(row.isSystem)
        Button(row.isPinned ? localized("Stop Showing in Menu Bar") : localized("Show in Menu Bar")) {
            onAction(.pin)
        }
        Button(localized("Rename")) { onAction(.beginRename) }
        Divider()
        Button(localized("Remove Time Zone"), role: .destructive) { onAction(.remove) }
            .disabled(!row.canRemove)
    }
}

extension ClockRowModel {
    /// "Current system time zone" or "Tomorrow · +15 h", relative to the Mac's time zone.
    func relativeText(localized: (String) -> String) -> String {
        if isSystem {
            return localized("Current system time zone")
        }
        var parts: [String] = []
        if let dayText = dayText(localized: localized) {
            parts.append(dayText)
        }
        if secondsFromSystem == 0 {
            parts.append(localized("Same time"))
        } else {
            let hours = TimeZoneClock.relativeHoursText(seconds: secondsFromSystem)
            parts.append(String(format: localized("%@ h"), hours))
        }
        return parts.joined(separator: " · ")
    }

    private func dayText(localized: (String) -> String) -> String? {
        switch dayOffset {
        case 0:
            return nil
        case -1:
            return localized("Yesterday")
        case 1:
            return localized("Tomorrow")
        case let days where days > 0:
            return String(format: localized("In %d days"), days)
        default:
            return String(format: localized("%d days ago"), -dayOffset)
        }
    }
}

struct Badge: View {
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
