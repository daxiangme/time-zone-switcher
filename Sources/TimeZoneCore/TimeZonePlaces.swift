import Foundation

/// A time zone as the add picker shows it: a city, the country it belongs to and the zone name.
public struct TimeZonePlace: Equatable, Sendable, Identifiable {
    public let identifier: String
    public let city: String
    public let country: String?
    public let zoneName: String
    public let area: TimeZoneArea
    /// Normalized strings the query is matched against, strongest match first.
    let cityKeys: [String]
    let countryKeys: [String]
    let otherKeys: [String]

    public var id: String { identifier }
}

/// The first component of an IANA identifier, in the order the picker lists them.
public enum TimeZoneArea: String, CaseIterable, Sendable {
    case asia = "Asia"
    case europe = "Europe"
    case america = "America"
    case africa = "Africa"
    case australia = "Australia"
    case pacific = "Pacific"
    case atlantic = "Atlantic"
    case indian = "Indian"
    case antarctica = "Antarctica"
    case arctic = "Arctic"
    case other = "Other"

    init(identifier: String) {
        let prefix = identifier.split(separator: "/").first.map(String.init) ?? ""
        self = identifier.contains("/") ? TimeZoneArea(rawValue: prefix) ?? .other : .other
    }
}

/// Every known time zone with localized names and search keys, built once per interface language.
public struct TimeZonePlaceIndex: Sendable {
    /// Big, commonly scheduled-against cities shown before the full list.
    public static let suggestedIdentifiers = [
        "Asia/Shanghai",
        "Asia/Hong_Kong",
        "Asia/Tokyo",
        "Asia/Singapore",
        "Asia/Kolkata",
        "Asia/Dubai",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "America/New_York",
        "America/Chicago",
        "America/Los_Angeles",
        "Australia/Sydney",
        "GMT"
    ]

    public let places: [TimeZonePlace]
    private let byIdentifier: [String: TimeZonePlace]

    public init(
        identifiers: [String] = ZoneTab.identifiers,
        locale: Locale,
        countryCodes: [String: String] = ZoneTab.countryCodes
    ) {
        let builder = PlaceBuilder(locale: locale, countryCodes: countryCodes)
        let areaOrder = Dictionary(uniqueKeysWithValues: TimeZoneArea.allCases.enumerated().map { ($1, $0) })
        places = identifiers
            .compactMap(builder.place(for:))
            .sorted { lhs, rhs in
                if lhs.area != rhs.area {
                    return areaOrder[lhs.area, default: 0] < areaOrder[rhs.area, default: 0]
                }
                return lhs.city.compare(rhs.city, options: [.caseInsensitive], locale: locale) == .orderedAscending
            }
        byIdentifier = Dictionary(places.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func place(for identifier: String) -> TimeZonePlace? {
        byIdentifier[identifier]
    }

    public var suggestions: [TimeZonePlace] {
        Self.suggestedIdentifiers.compactMap { byIdentifier[$0] }
    }

    /// City prefix beats city substring, which beats country, which beats zone name or identifier.
    /// Ties keep the area-then-city order of `places`.
    public func search(_ query: String) -> [TimeZonePlace] {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return places }

        return places.enumerated()
            .compactMap { offset, place -> (rank: Int, offset: Int, place: TimeZonePlace)? in
                guard let rank = Self.rank(place, for: needle) else { return nil }
                return (rank, offset, place)
            }
            .sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }
            .map(\.place)
    }

    private static func rank(_ place: TimeZonePlace, for needle: String) -> Int? {
        if place.cityKeys.contains(where: { $0.hasPrefix(needle) }) { return 0 }
        if place.cityKeys.contains(where: { $0.contains(needle) }) { return 1 }
        if place.countryKeys.contains(where: { $0.hasPrefix(needle) }) { return 2 }
        if place.countryKeys.contains(where: { $0.contains(needle) }) { return 3 }
        if place.otherKeys.contains(where: { $0.contains(needle) }) { return 4 }
        return nil
    }

    /// Lowercased, accent- and width-folded, without spaces or separators: "Los_Angeles" → "losangeles".
    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { !$0.isWhitespace && !"_-/'.,()".contains($0) }
    }
}

private struct PlaceBuilder {
    let locale: Locale
    let countryCodes: [String: String]
    private let english = Locale(identifier: "en")
    private let usesPinyin: Bool

    init(locale: Locale, countryCodes: [String: String]) {
        self.locale = locale
        self.countryCodes = countryCodes
        self.usesPinyin = locale.language.languageCode == .chinese
    }

    func place(for identifier: String) -> TimeZonePlace? {
        guard TimeZone(identifier: identifier) != nil else { return nil }

        let entry = TimeZoneCatalogEntry(identifier: identifier)
        let city = entry.localizedCityName(locale: locale)
        let code = countryCodes[identifier]
        let country = code.flatMap { locale.localizedString(forRegionCode: $0) }
        let englishCountry = code.flatMap { english.localizedString(forRegionCode: $0) }
        let zoneName = entry.displayName(locale: locale)

        return TimeZonePlace(
            identifier: identifier,
            city: city,
            country: country,
            zoneName: zoneName,
            area: TimeZoneArea(identifier: identifier),
            cityKeys: keys([city, entry.cityName], transliterating: city),
            countryKeys: keys([country, englishCountry, code], transliterating: country),
            otherKeys: keys(
                [zoneName, identifier, entry.displayName(locale: english), identifier == "GMT" ? "UTC" : nil],
                transliterating: nil
            )
        )
    }

    /// Adds full pinyin ("luoshanji") and initials ("lsj") for Chinese names.
    private func keys(_ values: [String?], transliterating name: String?) -> [String] {
        var result = values.compactMap { $0 }
        if usesPinyin, let name,
           let latin = name.applyingTransform(.mandarinToLatin, reverse: false)?
               .applyingTransform(.stripDiacritics, reverse: false),
           latin != name {
            result.append(latin)
            result.append(String(latin.split(separator: " ").compactMap(\.first)))
        }
        var seen = Set<String>()
        return result
            .map(TimeZonePlaceIndex.normalize)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

/// Canonical zones and their country codes from the system's tz database (`/usr/share/zoneinfo/zone.tab`).
public enum ZoneTab {
    public static let countryCodes: [String: String] = {
        guard let text = try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8) else {
            return [:]
        }
        return parse(text)
    }()

    /// zone.tab lists one canonical zone per place, while `knownTimeZoneIdentifiers` also carries
    /// aliases such as Asia/Calcutta and Asia/Chongqing that would show up as duplicates.
    public static var identifiers: [String] {
        guard !countryCodes.isEmpty else { return TimeZone.knownTimeZoneIdentifiers }
        return Array(countryCodes.keys) + ["GMT"]
    }

    /// Lines are `CC<TAB>coordinates<TAB>Area/City[<TAB>comment]`; `#` starts a comment line.
    static func parse(_ text: String) -> [String: String] {
        var codes: [String: String] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3 else { continue }
            codes[String(fields[2])] = String(fields[0])
        }
        return codes
    }
}
