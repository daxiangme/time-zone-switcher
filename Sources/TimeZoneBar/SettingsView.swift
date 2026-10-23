import SwiftUI
import TimeZoneCore

struct SettingsView: View {
    static let width: CGFloat = 500

    @ObservedObject var viewModel: TimeZoneBarViewModel
    @State private var customPattern: String = ""
    @State private var isShowingFormatHelp = false

    var body: some View {
        Form {
            Section(viewModel.localized("Menu Bar Display")) {
                MenuBarPreview(
                    iconName: viewModel.menuBarShowsIcon ? viewModel.menuBarIconName : nil,
                    text: viewModel.menuBarTimeText,
                    caption: previewCaption
                )

                Picker(viewModel.localized("Show"), selection: menuBarModeBinding) {
                    Text(viewModel.localized("Automatic")).tag(MenuBarDisplayMode.automatic)
                    Text(viewModel.localized("Icon Only")).tag(MenuBarDisplayMode.icon)
                    if !viewModel.savedIdentifiers.isEmpty {
                        Section(viewModel.localized("Always Show")) {
                            ForEach(viewModel.savedIdentifiers, id: \.self) { identifier in
                                Text(viewModel.displayName(for: identifier))
                                    .tag(MenuBarDisplayMode.pinned(identifier))
                            }
                        }
                    }
                }

                if viewModel.menuBarMode != .icon {
                    Toggle(viewModel.localized("Show Icon Next to Time"), isOn: iconBinding)
                }
            }

            Section {
                Picker(viewModel.localized("Time Format"), selection: presetBinding) {
                    ForEach(ClockFormatPreset.allCases, id: \.self) { preset in
                        FormatOption(
                            sample: preset == .custom ? nil : sample(for: preset),
                            title: viewModel.localized(preset.titleKey)
                        )
                        .tag(preset)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if viewModel.timeDisplayFormat.preset == .custom {
                    customPatternField
                }

                Toggle(viewModel.localized("Show Seconds"), isOn: secondsBinding)
            } header: {
                Text(viewModel.localized("Time Format"))
            } footer: {
                Text(viewModel.localized("Format applies to list"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(viewModel.localized("General")) {
                Picker(viewModel.localized("Interface Language"), selection: languageBinding) {
                    Text(viewModel.localized("Follow System")).tag(AppLanguage.system)
                    Text(viewModel.localized("Simplified Chinese")).tag(AppLanguage.simplifiedChinese)
                    Text(viewModel.localized("English")).tag(AppLanguage.english)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            customPattern = viewModel.timeDisplayFormat.customPattern
        }
    }

    // MARK: - Menu bar

    /// Says what the preview is and why, so "Automatic" showing only the icon isn't a surprise.
    private var previewCaption: String {
        guard let identifier = viewModel.menuBarIdentifier else {
            if case .automatic = viewModel.menuBarMode {
                return viewModel.localized("Automatic caption idle")
            }
            return viewModel.localized("Icon only caption")
        }
        return "\(viewModel.displayName(for: identifier)) · \(identifier)"
    }

    private var iconBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showsMenuBarIcon },
            set: { viewModel.setShowsMenuBarIcon($0) }
        )
    }

    private var menuBarModeBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { viewModel.menuBarMode },
            set: { viewModel.setMenuBarMode($0) }
        )
    }

    // MARK: - Format

    private var customPatternField: some View {
        HStack(spacing: 6) {
            TextField(
                viewModel.localized("Custom Pattern"),
                text: $customPattern,
                prompt: Text(verbatim: "HH:mm")
            )
            .font(.body.monospaced())
            .onChange(of: customPattern) { _, newValue in
                var format = viewModel.timeDisplayFormat
                format.customPattern = newValue
                viewModel.setTimeDisplayFormat(format)
            }

            Button {
                isShowingFormatHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .help(viewModel.localized("Format Help"))
            .popover(isPresented: $isShowingFormatHelp, arrowEdge: .trailing) {
                Text(viewModel.localized("Format Help"))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 260)
                    .padding(12)
            }
        }
    }

    private func sample(for preset: ClockFormatPreset) -> String {
        var format = viewModel.timeDisplayFormat
        format.preset = preset
        return TimeZoneClock.menuBarText(
            identifier: viewModel.previewIdentifier,
            at: viewModel.now,
            format: format,
            interfaceLanguage: viewModel.appLanguage
        ) ?? preset.basePattern
    }

    private var presetBinding: Binding<ClockFormatPreset> {
        Binding(
            get: { viewModel.timeDisplayFormat.preset },
            set: { preset in
                var format = viewModel.timeDisplayFormat
                format.preset = preset
                if preset == .custom, format.customPattern.isEmpty {
                    format.customPattern = customPattern
                }
                viewModel.setTimeDisplayFormat(format)
            }
        )
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
}

/// A strip that looks like the right end of the menu bar, with this app's item highlighted.
private struct MenuBarPreview: View {
    let iconName: String?
    let text: String?
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Spacer(minLength: 0)
                Image(systemName: "wifi")
                    .foregroundStyle(.tertiary)
                Image(systemName: "battery.75percent")
                    .foregroundStyle(.tertiary)
                HStack(spacing: 5) {
                    if let iconName {
                        Image(systemName: iconName)
                    }
                    if let text {
                        Text(text)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Image(systemName: "switch.2")
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(.bar, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text ?? caption)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct FormatOption: View {
    let sample: String?
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            if let sample {
                Text(sample.isEmpty ? "—" : sample)
                    .monospacedDigit()
                Text(title)
                    .foregroundStyle(.secondary)
            } else {
                Text(title)
            }
        }
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
