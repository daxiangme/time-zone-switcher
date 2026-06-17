import Foundation

public protocol SystemTimeZoneServicing {
    func currentTimeZoneIdentifier() throws -> String
    func setTimeZone(identifier: String) throws
}

public protocol TimeZoneStateStoring: AnyObject {
    var targetIdentifier: String { get set }
    var originalIdentifier: String? { get set }
    var isEnabled: Bool { get set }
}

public enum TimeZoneToolError: Error, LocalizedError, Equatable {
    case invalidTimeZoneIdentifier(String)
    case missingOriginalTimeZone
    case unableToReadCurrentTimeZone
    case commandFailed(String)

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
        }
    }
}

public final class InMemoryTimeZoneStore: TimeZoneStateStoring {
    public var targetIdentifier: String
    public var originalIdentifier: String?
    public var isEnabled: Bool

    public init(
        targetIdentifier: String,
        originalIdentifier: String? = nil,
        isEnabled: Bool = false
    ) {
        self.targetIdentifier = targetIdentifier
        self.originalIdentifier = originalIdentifier
        self.isEnabled = isEnabled
    }
}

public final class TimeZoneToggleCoordinator {
    private let store: TimeZoneStateStoring
    private let system: SystemTimeZoneServicing

    public init(store: TimeZoneStateStoring, system: SystemTimeZoneServicing) {
        self.store = store
        self.system = system
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    public func setTargetIdentifier(_ identifier: String) throws {
        try Self.validate(identifier)
        store.targetIdentifier = identifier

        if store.isEnabled {
            try system.setTimeZone(identifier: identifier)
        }
    }

    private func enable() throws {
        try Self.validate(store.targetIdentifier)

        if !store.isEnabled {
            store.originalIdentifier = try system.currentTimeZoneIdentifier()
        }

        try system.setTimeZone(identifier: store.targetIdentifier)
        store.isEnabled = true
    }

    private func disable() throws {
        guard let originalIdentifier = store.originalIdentifier else {
            throw TimeZoneToolError.missingOriginalTimeZone
        }

        try Self.validate(originalIdentifier)
        try system.setTimeZone(identifier: originalIdentifier)
        store.isEnabled = false
        store.originalIdentifier = nil
    }

    private static func validate(_ identifier: String) throws {
        guard TimeZone(identifier: identifier) != nil else {
            throw TimeZoneToolError.invalidTimeZoneIdentifier(identifier)
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

public final class UserDefaultsTimeZoneStore: TimeZoneStateStoring {
    private enum Key {
        static let targetIdentifier = "targetIdentifier"
        static let originalIdentifier = "originalIdentifier"
        static let isEnabled = "isEnabled"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var targetIdentifier: String {
        get { defaults.string(forKey: Key.targetIdentifier) ?? "America/Los_Angeles" }
        set { defaults.set(newValue, forKey: Key.targetIdentifier) }
    }

    public var originalIdentifier: String? {
        get { defaults.string(forKey: Key.originalIdentifier) }
        set { defaults.set(newValue, forKey: Key.originalIdentifier) }
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
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
