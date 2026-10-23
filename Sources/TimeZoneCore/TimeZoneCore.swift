import Foundation

/// Main-actor bound so callers can await `setTimeZone` without handing the service across threads;
/// the real implementation waits for the authorization prompt without blocking the main thread.
@MainActor
public protocol SystemTimeZoneServicing {
    func currentTimeZoneIdentifier() throws -> String
    func setTimeZone(identifier: String) async throws
}

public enum TimeZoneToolError: Error, LocalizedError, Equatable {
    case invalidTimeZoneIdentifier(String)
    case missingOriginalTimeZone
    case unableToReadCurrentTimeZone
    case commandFailed(String)
    case cannotRemoveHomeTimeZone
    /// The user dismissed the administrator authorization prompt.
    case cancelled

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
        case .cancelled:
            return "The administrator authorization was cancelled."
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

    /// The localized exemplar city, e.g. 洛杉矶 / Los Angeles. Zones without a city
    /// (`UTC`, `Etc/GMT+5`) fall back to the localized zone name.
    public func localizedCityName(locale: Locale = TimeZoneDisplayLocale.current) -> String {
        guard identifier.contains("/"), !identifier.hasPrefix("Etc/"),
              let timeZone = TimeZone(identifier: identifier)
        else {
            return displayName(locale: locale)
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "VVV"
        let city = formatter.string(from: Date())
        return city.isEmpty ? cityName : city
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

    public func setTimeZone(identifier: String) async throws {
        guard TimeZone(identifier: identifier) != nil else {
            throw TimeZoneToolError.invalidTimeZoneIdentifier(identifier)
        }

        let command = "/usr/sbin/systemsetup -settimezone \(Self.shellQuoted(identifier))"
        let script = "do shell script \(Self.appleScriptQuoted(command)) with administrator privileges"
        try await Self.runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
    }

    nonisolated static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    nonisolated static func appleScriptQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Suspends until the process exits instead of blocking a thread, so the UI keeps running
    /// while the authorization prompt is up.
    private nonisolated static func runProcess(executable: String, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                guard process.terminationStatus != 0 else {
                    continuation.resume()
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(throwing: commandError(output: output))
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// osascript reports a dismissed authorization prompt as error -128 ("User canceled.").
    nonisolated static func commandError(output: String) -> TimeZoneToolError {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("(-128)") {
            return .cancelled
        }
        return .commandFailed(trimmed)
    }
}
