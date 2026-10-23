import Foundation

public enum MenuBarDisplayMode: Hashable, Sendable {
    case automatic
    case icon
    case pinned(String)
}

public enum MenuBarPresentation: Equatable, Sendable {
    case icon(overrideActive: Bool)
    case time(String)
}

public enum MenuBarDisplayResolver {
    public static func presentation(
        mode: MenuBarDisplayMode,
        isEnabled: Bool,
        systemIdentifier: String,
        savedIdentifiers: [String]
    ) -> MenuBarPresentation {
        switch mode {
        case .icon:
            return .icon(overrideActive: isEnabled)
        case .pinned(let identifier):
            guard savedIdentifiers.contains(identifier) else {
                return automaticPresentation(isEnabled: isEnabled, systemIdentifier: systemIdentifier)
            }
            return .time(identifier)
        case .automatic:
            return automaticPresentation(isEnabled: isEnabled, systemIdentifier: systemIdentifier)
        }
    }

    private static func automaticPresentation(
        isEnabled: Bool,
        systemIdentifier: String
    ) -> MenuBarPresentation {
        guard isEnabled, TimeZone(identifier: systemIdentifier) != nil else {
            return .icon(overrideActive: isEnabled)
        }
        return .time(systemIdentifier)
    }
}

public enum AppLanguage: String, Equatable, Sendable {
    case system
    case simplifiedChinese
    case english

    public var locale: Locale {
        switch self {
        case .system:
            return TimeZoneDisplayLocale.current
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

public enum ClockFormatPreset: String, Equatable, Sendable, CaseIterable {
    case timeOnly
    case abbreviationAndTime
    case compactDate
    case chineseDateTime
    case englishDateTime
    case custom

    public var basePattern: String {
        switch self {
        case .timeOnly:
            return "HH:mm"
        case .abbreviationAndTime:
            return "z HH:mm"
        case .compactDate:
            return "MM-dd HH:mm"
        case .chineseDateTime:
            return "M月d日 E a h:mm"
        case .englishDateTime:
            return "E, MMM d, h:mm a"
        case .custom:
            return ""
        }
    }
}

public struct TimeDisplayFormat: Equatable, Sendable {
    public var preset: ClockFormatPreset
    public var showsSeconds: Bool
    public var customPattern: String

    public init(preset: ClockFormatPreset, showsSeconds: Bool, customPattern: String = "") {
        self.preset = preset
        self.showsSeconds = showsSeconds
        self.customPattern = customPattern
    }

    public static let standard = TimeDisplayFormat(
        preset: .abbreviationAndTime,
        showsSeconds: false,
        customPattern: ""
    )

    public func pattern() -> String {
        let base = preset == .custom
            ? (customPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "HH:mm" : customPattern)
            : preset.basePattern
        return Self.applyingSeconds(base, showsSeconds: showsSeconds)
    }

    public func renderingLocale(interfaceLanguage: AppLanguage) -> Locale {
        switch preset {
        case .chineseDateTime:
            return Locale(identifier: "zh-Hans")
        case .englishDateTime:
            return Locale(identifier: "en_US")
        case .custom:
            return interfaceLanguage.locale
        case .timeOnly, .abbreviationAndTime, .compactDate:
            return Locale(identifier: "en_US")
        }
    }

    public func updatesEverySecond() -> Bool {
        pattern().contains("ss")
    }

    public static func applyingSeconds(_ pattern: String, showsSeconds: Bool) -> String {
        guard showsSeconds else { return pattern }
        guard let range = pattern.range(of: #"(?<!M)mm(?!:ss)"#, options: .regularExpression) else {
            return pattern
        }
        var result = pattern
        result.replaceSubrange(range, with: "mm:ss")
        return result
    }

    public static func migratedFromLegacy(
        content: String?,
        hourCycle: String?,
        showsSeconds: Bool
    ) -> TimeDisplayFormat {
        if content == "time", hourCycle == "twelve" {
            return TimeDisplayFormat(preset: .custom, showsSeconds: showsSeconds, customPattern: "h:mm a")
        }
        if content == "time" {
            return TimeDisplayFormat(preset: .timeOnly, showsSeconds: showsSeconds)
        }
        if content == nil, hourCycle == nil {
            return TimeDisplayFormat(preset: .abbreviationAndTime, showsSeconds: showsSeconds)
        }
        return TimeDisplayFormat(preset: .abbreviationAndTime, showsSeconds: showsSeconds)
    }
}

public protocol TimeZoneStateStoring: AnyObject {
    var savedIdentifiers: [String] { get set }
    var homeIdentifier: String? { get set }
    var isEnabled: Bool { get set }
    var menuBarMode: MenuBarDisplayMode { get set }
    var timeDisplayFormat: TimeDisplayFormat { get set }
    var appLanguage: AppLanguage { get set }
    var customLabels: [String: String] { get set }
    /// Whether the clock icon sits next to the time in the menu bar. Icon-only mode always shows it.
    var showsMenuBarIcon: Bool { get set }
}

public final class InMemoryTimeZoneStore: TimeZoneStateStoring {
    public var savedIdentifiers: [String]
    public var homeIdentifier: String?
    public var isEnabled: Bool
    public var menuBarMode: MenuBarDisplayMode
    public var timeDisplayFormat: TimeDisplayFormat
    public var appLanguage: AppLanguage
    public var customLabels: [String: String]
    public var showsMenuBarIcon: Bool

    public init(
        savedIdentifiers: [String] = [],
        homeIdentifier: String? = nil,
        isEnabled: Bool = false,
        menuBarMode: MenuBarDisplayMode = .automatic,
        timeDisplayFormat: TimeDisplayFormat = .standard,
        appLanguage: AppLanguage = .system,
        customLabels: [String: String] = [:],
        showsMenuBarIcon: Bool = true
    ) {
        self.savedIdentifiers = savedIdentifiers
        self.homeIdentifier = homeIdentifier
        self.isEnabled = isEnabled
        self.menuBarMode = menuBarMode
        self.timeDisplayFormat = timeDisplayFormat
        self.appLanguage = appLanguage
        self.customLabels = customLabels
        self.showsMenuBarIcon = showsMenuBarIcon
    }
}

public final class UserDefaultsTimeZoneStore: TimeZoneStateStoring {
    private enum Key {
        static let savedIdentifiers = "savedIdentifiers"
        static let homeIdentifier = "homeIdentifier"
        static let isEnabled = "isEnabled"
        static let menuBarMode = "menuBarMode"
        static let pinnedMenuBarIdentifier = "pinnedMenuBarIdentifier"
        static let targetIdentifier = "targetIdentifier"
        static let originalIdentifier = "originalIdentifier"
        static let hourCycle = "hourCycle"
        static let showsSeconds = "showsSeconds"
        static let clockContent = "clockContent"
        static let clockPreset = "clockPreset"
        static let customPattern = "customPattern"
        static let appLanguage = "appLanguage"
        static let customLabels = "customLabels"
        static let showsMenuBarIcon = "showsMenuBarIcon"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyStateIfNeeded()
    }

    public var savedIdentifiers: [String] {
        get { defaults.stringArray(forKey: Key.savedIdentifiers) ?? [] }
        set { defaults.set(newValue, forKey: Key.savedIdentifiers) }
    }

    public var homeIdentifier: String? {
        get { defaults.string(forKey: Key.homeIdentifier) }
        set { defaults.set(newValue, forKey: Key.homeIdentifier) }
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }

    public var menuBarMode: MenuBarDisplayMode {
        get {
            switch defaults.string(forKey: Key.menuBarMode) {
            case "icon":
                return .icon
            case "pinned":
                guard let identifier = defaults.string(forKey: Key.pinnedMenuBarIdentifier) else {
                    return .automatic
                }
                return .pinned(identifier)
            default:
                return .automatic
            }
        }
        set {
            switch newValue {
            case .automatic:
                defaults.set("automatic", forKey: Key.menuBarMode)
                defaults.removeObject(forKey: Key.pinnedMenuBarIdentifier)
            case .icon:
                defaults.set("icon", forKey: Key.menuBarMode)
                defaults.removeObject(forKey: Key.pinnedMenuBarIdentifier)
            case .pinned(let identifier):
                defaults.set("pinned", forKey: Key.menuBarMode)
                defaults.set(identifier, forKey: Key.pinnedMenuBarIdentifier)
            }
        }
    }

    public var timeDisplayFormat: TimeDisplayFormat {
        get {
            let showsSeconds = defaults.bool(forKey: Key.showsSeconds)
            if let preset = defaults.string(forKey: Key.clockPreset) {
                return TimeDisplayFormat(
                    preset: ClockFormatPreset(rawValue: preset) ?? .abbreviationAndTime,
                    showsSeconds: showsSeconds,
                    customPattern: defaults.string(forKey: Key.customPattern) ?? ""
                )
            }
            let hasLegacyFormat = defaults.object(forKey: Key.clockContent) != nil
                || defaults.object(forKey: Key.hourCycle) != nil
                || defaults.object(forKey: Key.showsSeconds) != nil
            guard hasLegacyFormat else { return .standard }
            return TimeDisplayFormat.migratedFromLegacy(
                content: defaults.string(forKey: Key.clockContent),
                hourCycle: defaults.string(forKey: Key.hourCycle),
                showsSeconds: showsSeconds
            )
        }
        set {
            defaults.set(newValue.preset.rawValue, forKey: Key.clockPreset)
            defaults.set(newValue.showsSeconds, forKey: Key.showsSeconds)
            defaults.set(newValue.customPattern, forKey: Key.customPattern)
        }
    }

    public var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: Key.appLanguage) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.appLanguage) }
    }

    public var customLabels: [String: String] {
        get { defaults.dictionary(forKey: Key.customLabels) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Key.customLabels) }
    }

    public var showsMenuBarIcon: Bool {
        get { defaults.object(forKey: Key.showsMenuBarIcon) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showsMenuBarIcon) }
    }

    private func migrateLegacyStateIfNeeded() {
        guard defaults.object(forKey: Key.savedIdentifiers) == nil else { return }
        guard let target = defaults.string(forKey: Key.targetIdentifier), !target.isEmpty else { return }

        let original = defaults.string(forKey: Key.originalIdentifier)
        if defaults.bool(forKey: Key.isEnabled), let original, !original.isEmpty {
            var saved = [original]
            if original != target {
                saved.append(target)
            }
            defaults.set(saved, forKey: Key.savedIdentifiers)
            defaults.set(original, forKey: Key.homeIdentifier)
        } else {
            defaults.set([target], forKey: Key.savedIdentifiers)
        }
    }
}

@MainActor
public final class WorldClockCoordinator {
    private let store: TimeZoneStateStoring
    private let system: SystemTimeZoneServicing

    public init(store: TimeZoneStateStoring, system: SystemTimeZoneServicing) {
        self.store = store
        self.system = system
    }

    public func add(_ identifier: String) throws {
        try Self.validate(identifier)
        guard !store.savedIdentifiers.contains(identifier) else { return }
        store.savedIdentifiers.append(identifier)
    }

    public func remove(_ identifier: String) async throws {
        guard store.savedIdentifiers.contains(identifier) else { return }

        if store.isEnabled, store.homeIdentifier == identifier {
            throw TimeZoneToolError.cannotRemoveHomeTimeZone
        }

        if store.isEnabled {
            let current = try system.currentTimeZoneIdentifier()
            if current == identifier {
                try await restoreHomeTimeZone()
            }
        }

        let saved = store.savedIdentifiers.filter { $0 != identifier }
        store.savedIdentifiers = saved
        var labels = store.customLabels
        if labels.removeValue(forKey: identifier) != nil {
            store.customLabels = labels
        }

        guard case .pinned(let pinned) = store.menuBarMode else { return }
        if pinned == identifier || saved.isEmpty {
            store.menuBarMode = .automatic
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let identifiers = store.savedIdentifiers
        guard !source.isEmpty, source.allSatisfy({ identifiers.indices.contains($0) }) else { return }

        var items = identifiers
        let moving = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }

        let preceding = source.filter { $0 < destination }.count
        var target = destination - preceding
        if target < 0 {
            target = 0
        } else if target > items.count {
            target = items.count
        }
        items.insert(contentsOf: moving, at: target)
        store.savedIdentifiers = items
    }

    public func applySystemTimeZone(_ identifier: String) async throws {
        try Self.validate(identifier)
        let current = try system.currentTimeZoneIdentifier()

        if current == identifier {
            if !store.savedIdentifiers.contains(identifier) {
                store.savedIdentifiers.append(identifier)
            }
            return
        }

        if store.isEnabled, store.homeIdentifier == identifier {
            try await restoreHomeTimeZone()
            return
        }

        var saved = store.savedIdentifiers
        if !saved.contains(identifier) {
            saved.append(identifier)
        }

        let home: String?
        if store.isEnabled {
            home = store.homeIdentifier
        } else {
            if !saved.contains(current) {
                saved.insert(current, at: 0)
            }
            try Self.validate(current)
            home = current
        }

        try await system.setTimeZone(identifier: identifier)
        store.savedIdentifiers = saved
        store.homeIdentifier = home
        store.isEnabled = true
    }

    public func restoreHomeTimeZone() async throws {
        guard store.isEnabled else { return }
        guard let homeIdentifier = store.homeIdentifier else {
            throw TimeZoneToolError.missingOriginalTimeZone
        }

        try Self.validate(homeIdentifier)
        try await system.setTimeZone(identifier: homeIdentifier)
        store.isEnabled = false
        store.homeIdentifier = nil
    }

    public func setMenuBarMode(_ mode: MenuBarDisplayMode) {
        if case .pinned(let identifier) = mode, !store.savedIdentifiers.contains(identifier) {
            return
        }
        store.menuBarMode = mode
    }

    private static func validate(_ identifier: String) throws {
        guard TimeZone(identifier: identifier) != nil else {
            throw TimeZoneToolError.invalidTimeZoneIdentifier(identifier)
        }
    }
}

public struct TimeZoneClockFace: Equatable, Sendable {
    public let timeText: String
    public let abbreviation: String
    public let offsetText: String
    public let dateText: String?

    public init(timeText: String, abbreviation: String, offsetText: String, dateText: String?) {
        self.timeText = timeText
        self.abbreviation = abbreviation
        self.offsetText = offsetText
        self.dateText = dateText
    }
}

public enum TimeZoneClock {
    public static func face(
        identifier: String,
        at date: Date,
        interfaceLanguage: AppLanguage = .system,
        systemTimeZone: TimeZone,
        format: TimeDisplayFormat = .standard
    ) -> TimeZoneClockFace? {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }

        let offset = offsetText(secondsFromGMT: timeZone.secondsFromGMT(for: date))
        let abbreviation = abbreviationText(timeZone.abbreviation(for: date), offsetText: offset)
        let locale = format.renderingLocale(interfaceLanguage: interfaceLanguage)
        let timeText = render(
            date,
            timeZone: timeZone,
            pattern: clockPattern(for: format.pattern()),
            locale: locale
        )
        let dateText = calendarDaysDiffer(date, timeZone: timeZone, systemTimeZone: systemTimeZone)
            ? render(date, timeZone: timeZone, pattern: "M/d", locale: locale)
            : nil
        return TimeZoneClockFace(
            timeText: timeText,
            abbreviation: abbreviation,
            offsetText: offset,
            dateText: dateText
        )
    }

    public static func menuBarText(
        identifier: String,
        at date: Date,
        format: TimeDisplayFormat = .standard,
        interfaceLanguage: AppLanguage = .system
    ) -> String? {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        let rendered = render(
            date,
            timeZone: timeZone,
            pattern: format.pattern(),
            locale: format.renderingLocale(interfaceLanguage: interfaceLanguage)
        )
        return rendered.isEmpty ? nil : rendered
    }

    public static func offsetText(secondsFromGMT seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        if minutes == 0 {
            return "UTC\(sign)\(hours)"
        }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    static func abbreviationText(_ abbreviation: String?, offsetText: String) -> String {
        guard let abbreviation, !abbreviation.isEmpty else {
            return offsetText
        }
        return abbreviation
    }

    static func clockPattern(for pattern: String) -> String {
        let usesTwelveHour = pattern.range(of: #"(?<![Hh])h"#, options: .regularExpression) != nil
        let includesPeriod = pattern.range(of: #"(?<![A-Za-z])a(?![A-Za-z])"#, options: .regularExpression) != nil
        let includesSeconds = pattern.contains("ss")
        if usesTwelveHour || includesPeriod {
            let periodBeforeHour = periodComesBeforeHour(in: pattern)
            if periodBeforeHour {
                return includesSeconds ? "a h:mm:ss" : "a h:mm"
            }
            return includesSeconds ? "h:mm:ss a" : "h:mm a"
        }
        return includesSeconds ? "HH:mm:ss" : "HH:mm"
    }

    private static func periodComesBeforeHour(in pattern: String) -> Bool {
        guard let period = pattern.range(of: #"(?<![A-Za-z])a(?![A-Za-z])"#, options: .regularExpression),
              let hour = pattern.range(of: #"(?<![Hh])h"#, options: .regularExpression)
        else {
            return false
        }
        return period.lowerBound < hour.lowerBound
    }

    private static func render(_ date: Date, timeZone: TimeZone, pattern: String, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private static func calendarDaysDiffer(
        _ date: Date,
        timeZone: TimeZone,
        systemTimeZone: TimeZone
    ) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let localDay = calendar.dateComponents([.year, .month, .day], from: date)
        calendar.timeZone = systemTimeZone
        let systemDay = calendar.dateComponents([.year, .month, .day], from: date)
        return localDay.year != systemDay.year
            || localDay.month != systemDay.month
            || localDay.day != systemDay.day
    }
}
