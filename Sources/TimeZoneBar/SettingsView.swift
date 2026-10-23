import SwiftUI
import TimeZoneCore

struct SettingsView: View {
    @ObservedObject var viewModel: TimeZoneBarViewModel
    @State private var customPattern: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                preview
                formatSection
                languageSection
                menuBarSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 620)
        .onAppear {
            customPattern = viewModel.timeDisplayFormat.customPattern
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.menuBarPreview.isEmpty ? "—" : viewModel.menuBarPreview)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Text(previewCaption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var previewCaption: String {
        let name = viewModel.displayName(for: viewModel.previewIdentifier)
        return "\(name) · \(viewModel.previewIdentifier)"
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.localized("Time Format"))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ClockFormatPreset.allCases, id: \.self) { preset in
                    FormatCard(
                        title: viewModel.localized(preset.titleKey),
                        sample: sample(for: preset),
                        pattern: preset == .custom ? viewModel.localized("Custom Pattern") : preset.basePattern,
                        isSelected: viewModel.timeDisplayFormat.preset == preset
                    ) {
                        select(preset)
                    }
                }
            }

            Toggle(viewModel.localized("Show Seconds"), isOn: secondsBinding)
                .toggleStyle(.switch)

            if viewModel.timeDisplayFormat.preset == .custom {
                TextField(viewModel.localized("Custom Pattern"), text: $customPattern)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitCustomPattern() }
                    .onChange(of: customPattern) { _, newValue in
                        var format = viewModel.timeDisplayFormat
                        format.customPattern = newValue
                        viewModel.setTimeDisplayFormat(format)
                    }
            }

            Text(viewModel.localized("Format Help"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.localized("Interface Language"))
                .font(.headline)

            Picker(viewModel.localized("Interface Language"), selection: languageBinding) {
                Text(viewModel.localized("Follow System")).tag(AppLanguage.system)
                Text(viewModel.localized("Simplified Chinese")).tag(AppLanguage.simplifiedChinese)
                Text(viewModel.localized("English")).tag(AppLanguage.english)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.localized("Menu Bar Display"))
                .font(.headline)

            if case .pinned(let identifier) = viewModel.menuBarMode {
                Text(String(format: viewModel.localized("Pinned to %@"), viewModel.displayName(for: identifier)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker(viewModel.localized("Menu Bar Display"), selection: menuBarModeBinding) {
                Text(viewModel.localized("Automatic")).tag(MenuBarModeChoice.automatic)
                Text(viewModel.localized("Icon Only")).tag(MenuBarModeChoice.icon)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func sample(for preset: ClockFormatPreset) -> String {
        var format = viewModel.timeDisplayFormat
        format.preset = preset
        if preset != .custom {
            format.customPattern = ""
        }
        return TimeZoneClock.menuBarText(
            identifier: viewModel.previewIdentifier,
            at: viewModel.now,
            format: format,
            interfaceLanguage: viewModel.appLanguage
        ) ?? preset.basePattern
    }

    private func select(_ preset: ClockFormatPreset) {
        var format = viewModel.timeDisplayFormat
        format.preset = preset
        if preset == .custom, format.customPattern.isEmpty {
            format.customPattern = customPattern
        }
        viewModel.setTimeDisplayFormat(format)
    }

    private func commitCustomPattern() {
        var format = viewModel.timeDisplayFormat
        format.preset = .custom
        format.customPattern = customPattern
        viewModel.setTimeDisplayFormat(format)
    }

    private var secondsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.timeDisplayFormat.showsSeconds },
            set: { value in
                var format = viewModel.timeDisplayFormat
                format.showsSeconds = value
                viewModel.setTimeDisplayFormat(format)
            }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { viewModel.appLanguage },
            set: { viewModel.setAppLanguage($0) }
        )
    }

    private var menuBarModeBinding: Binding<MenuBarModeChoice> {
        Binding(
            get: {
                switch viewModel.menuBarMode {
                case .icon:
                    return .icon
                case .automatic:
                    return .automatic
                case .pinned:
                    return .pinned
                }
            },
            set: { choice in
                switch choice {
                case .automatic:
                    viewModel.setMenuBarMode(.automatic)
                case .icon:
                    viewModel.setMenuBarMode(.icon)
                case .pinned:
                    break
                }
            }
        )
    }
}

private enum MenuBarModeChoice: Hashable {
    case automatic
    case icon
    case pinned
}

private struct FormatCard: View {
    let title: String
    let sample: String
    let pattern: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(sample.isEmpty ? "—" : sample)
                    .font(.body.monospacedDigit())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(pattern)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension ClockFormatPreset {
    var titleKey: String {
        switch self {
        case .timeOnly:
            return "Time Only"
        case .abbreviationAndTime:
            return "Abbreviation and Time"
        case .compactDate:
            return "Compact Date"
        case .chineseDateTime:
            return "Chinese Date Time"
        case .englishDateTime:
            return "English Date Time"
        case .custom:
            return "Custom"
        }
    }
}
