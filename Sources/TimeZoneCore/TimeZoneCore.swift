import Foundation

public protocol SystemTimeZoneServicing {
    func currentTimeZoneIdentifier() throws -> String
    func setTimeZone(identifier: String) throws
}

public enum TimeZoneToolError: Error, LocalizedError, Equatable {
    case invalidTimeZoneIdentifier(String)
    case missingOriginalTimeZone
    case unableToReadCurrentTimeZone
    case commandFailed(String)
    case cannotRemoveHomeTimeZone

    public var errorDescription: String? {
        switch self {
        case .invalidTimeZoneIdentifier(let identifier):
            return "\"\(identifier)\" is not a valid time zone identifier."
        case .missingOriginalTimeZone:
            return "No previously recorded time zone is available to restore."
        case .unableToReadCurrentTimeZone:
            return "Could not read the current system time zone."
        case .commandFailed(let output):
            return output.isEmpty ? "The system time zone command failed." : output
        case .cannotRemoveHomeTimeZone:
            return "The home time zone can't be removed while the override is active."
        }
    }
}

public struct TimeZoneCatalog {
    private let entries: [TimeZoneCatalogEntry]
    private let locale: Locale

    public init(
        identifiers: [String] = TimeZone.knownTimeZoneIdentifiers,
        locale: Locale = TimeZoneDisplayLocale.current
    ) {
        self.locale = locale
        self.entries = identifiers
            .map(TimeZoneCatalogEntry.init(identifier:))
            .sorted { $0.identifier.localizedCaseInsensitiveCompare($1.identifier) == .orderedAscending }
    }

    public func search(_ query: String) -> [TimeZoneCatalogEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            entry.identifier.localizedCaseInsensitiveContains(trimmedQuery)
                || entry.displayName(locale: locale).localizedCaseInsensitiveContains(trimmedQuery)
                || entry.cityName.localizedCaseInsensitiveContains(trimmedQuery)
                || entry.regionName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

public struct TimeZoneCatalogEntry: Equatable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }

    public var regionName: String {
        identifier.split(separator: "/", maxSplits: 1).first.map(String.init) ?? identifier
    }

    public var cityName: String {
        let value = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return value.replacingOccurrences(of: "_", with: " ")
    }

    public func displayName(locale: Locale = TimeZoneDisplayLocale.current) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else {
            return cityName
        }

        return timeZone.localizedName(for: .generic, locale: locale)
            ?? timeZone.localizedName(for: .standard, locale: locale)
            ?? cityName
    }
}

public enum TimeZoneDisplayLocale {
    public static var current: Locale {
        let languages = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
            ?? Locale.preferredLanguages
        return preferred(from: languages)
    }

    public static func preferred(from languages: [String]) -> Locale {
        guard let identifier = languages.first, !identifier.isEmpty else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: identifier)
    }
}

public final class LocalSystemTimeZoneService: SystemTimeZoneServicing {
    public init() {}

    public func currentTimeZoneIdentifier() throws -> String {
        let localTimePath = "/etc/localtime"

        if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: localTimePath) {
            for prefix in ["/var/db/timezone/zoneinfo/", "/usr/share/zoneinfo/"] where destination.hasPrefix(prefix) {
                return String(destination.dropFirst(prefix.count))
            }
        }

        let currentIdentifier = TimeZone.current.identifier
        if TimeZone(identifier: currentIdentifier) != nil {
            return currentIdentifier
        }

        throw TimeZoneToolError.unableToReadCurrentTimeZone
    }

    public func setTimeZone(identifier: String) throws {
        guard TimeZone(identifier: identifier) != nil else {
            throw TimeZoneToolError.invalidTimeZoneIdentifier(identifier)
        }

        let command = "/usr/sbin/systemsetup -settimezone \(Self.shellQuoted(identifier))"
        let script = "do shell script \(Self.appleScriptQuoted(command)) with administrator privileges"
        try Self.runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func appleScriptQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw TimeZoneToolError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
