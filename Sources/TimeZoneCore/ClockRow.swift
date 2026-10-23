import Foundation

/// Everything a clock row in the popover shows, derived from the saved state and the current time.
public struct ClockRowModel: Equatable, Sendable, Identifiable {
    public let identifier: String
    /// The custom label when one is set, otherwise the localized city name.
    public let title: String
    public let cityName: String
    public let hasCustomLabel: Bool
    public let timeText: String
    public let utcOffsetText: String
    /// Calendar days between this zone and the system zone: -1 is yesterday, 1 is tomorrow.
    public let dayOffset: Int
    /// How far this zone's wall clock is ahead of the system zone, in seconds.
    public let secondsFromSystem: Int
    public let isDaytime: Bool
    /// This zone is the current Mac time zone.
    public let isSystem: Bool
    /// This zone is the one to restore while an override is active.
    public let isHome: Bool
    public let isPinned: Bool
    public let canRemove: Bool

    public var id: String { identifier }

    public init(
        identifier: String,
        title: String,
        cityName: String,
        hasCustomLabel: Bool,
        timeText: String,
        utcOffsetText: String,
        dayOffset: Int,
        secondsFromSystem: Int,
        isDaytime: Bool,
        isSystem: Bool,
        isHome: Bool,
        isPinned: Bool,
        canRemove: Bool
    ) {
        self.identifier = identifier
        self.title = title
        self.cityName = cityName
        self.hasCustomLabel = hasCustomLabel
        self.timeText = timeText
        self.utcOffsetText = utcOffsetText
        self.dayOffset = dayOffset
        self.secondsFromSystem = secondsFromSystem
        self.isDaytime = isDaytime
        self.isSystem = isSystem
        self.isHome = isHome
        self.isPinned = isPinned
        self.canRemove = canRemove
    }

    public static func rows(
        savedIdentifiers: [String],
        systemIdentifier: String,
        homeIdentifier: String?,
        isEnabled: Bool,
        menuBarMode: MenuBarDisplayMode,
        customLabels: [String: String],
        at date: Date,
        format: TimeDisplayFormat = .standard,
        interfaceLanguage: AppLanguage = .system
    ) -> [ClockRowModel] {
        let systemTimeZone = TimeZone(identifier: systemIdentifier) ?? .current
        let pinnedIdentifier: String?
        if case .pinned(let identifier) = menuBarMode {
            pinnedIdentifier = identifier
        } else {
            pinnedIdentifier = nil
        }

        return savedIdentifiers.compactMap { identifier in
            guard let timeZone = TimeZone(identifier: identifier),
                  let face = TimeZoneClock.face(
                      identifier: identifier,
                      at: date,
                      interfaceLanguage: interfaceLanguage,
                      systemTimeZone: systemTimeZone,
                      format: format
                  )
            else {
                return nil
            }

            let entry = TimeZoneCatalogEntry(identifier: identifier)
            let cityName = entry.localizedCityName(locale: interfaceLanguage.locale)
            let customLabel = customLabels[identifier]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isHome = isEnabled && identifier == homeIdentifier

            return ClockRowModel(
                identifier: identifier,
                title: customLabel.isEmpty ? cityName : customLabel,
                cityName: cityName,
                hasCustomLabel: !customLabel.isEmpty,
                timeText: face.timeText,
                utcOffsetText: face.offsetText,
                dayOffset: TimeZoneClock.dayOffset(at: date, in: timeZone, from: systemTimeZone),
                secondsFromSystem: timeZone.secondsFromGMT(for: date) - systemTimeZone.secondsFromGMT(for: date),
                isDaytime: TimeZoneClock.isDaytime(at: date, in: timeZone),
                isSystem: identifier == systemIdentifier,
                isHome: isHome,
                isPinned: identifier == pinnedIdentifier,
                canRemove: !isHome
            )
        }
    }
}

extension TimeZoneClock {
    /// Signed hour difference for display next to a unit: "+15", "-3", "+5:30", "-9:30".
    /// Zero has no sign; callers usually show "same time" instead.
    public static func relativeHoursText(seconds: Int) -> String {
        guard seconds != 0 else { return "0" }
        let sign = seconds > 0 ? "+" : "-"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        if minutes == 0 {
            return "\(sign)\(hours)"
        }
        return String(format: "%@%d:%02d", sign, hours, minutes)
    }

    static func dayOffset(at date: Date, in timeZone: TimeZone, from systemTimeZone: TimeZone) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let localDay = utc.date(from: calendarDay(of: date, in: timeZone)),
              let systemDay = utc.date(from: calendarDay(of: date, in: systemTimeZone))
        else {
            return 0
        }
        return utc.dateComponents([.day], from: systemDay, to: localDay).day ?? 0
    }

    /// 06:00 up to 18:00 local time counts as day.
    static func isDaytime(at date: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return (6..<18).contains(calendar.component(.hour, from: date))
    }

    private static func calendarDay(of date: Date, in timeZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.year, .month, .day], from: date)
    }
}
