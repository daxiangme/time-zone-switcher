import AppKit
import Foundation
import TimeZoneCore

@MainActor
final class TimeZoneBarViewModel: ObservableObject {
    @Published private(set) var savedIdentifiers: [String] = []
    @Published private(set) var homeIdentifier: String?
    @Published private(set) var systemIdentifier = "Unknown"
    @Published private(set) var isEnabled = false
    @Published private(set) var menuBarMode: MenuBarDisplayMode = .automatic
    @Published private(set) var timeDisplayFormat: TimeDisplayFormat = .standard
    @Published private(set) var appLanguage: AppLanguage = .system
    @Published private(set) var customLabels: [String: String] = [:]
    @Published private(set) var isWorking = false
    @Published private(set) var now = Date()
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let store: TimeZoneStateStoring
    private let system: SystemTimeZoneServicing
    private let coordinator: WorldClockCoordinator
    nonisolated(unsafe) private var clockTimer: Timer?
    nonisolated(unsafe) private var notificationObservers: [any NSObjectProtocol] = []

    init(
        store: TimeZoneStateStoring = UserDefaultsTimeZoneStore(),
        system: SystemTimeZoneServicing = LocalSystemTimeZoneService()
    ) {
        self.store = store
        self.system = system
        self.coordinator = WorldClockCoordinator(store: store, system: system)
        refresh()
        observeSystemChanges()
        scheduleClockUpdate()
    }

    deinit {
        clockTimer?.invalidate()
        let observers = notificationObservers
        notificationObservers = []
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var filteredEntries: [TimeZoneCatalogEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let catalog = TimeZoneCatalog(locale: appLanguage.locale)
        return Array(catalog.search(searchText).prefix(8))
    }

    var previewIdentifier: String {
        switch MenuBarDisplayResolver.presentation(
            mode: menuBarMode,
            isEnabled: isEnabled,
            systemIdentifier: systemIdentifier,
            savedIdentifiers: savedIdentifiers
        ) {
        case .time(let identifier):
            return identifier
        case .icon:
            return savedIdentifiers.first ?? systemIdentifier
        }
    }

    var menuBarPreview: String {
        TimeZoneClock.menuBarText(
            identifier: previewIdentifier,
            at: now,
            format: timeDisplayFormat,
            interfaceLanguage: appLanguage
        ) ?? ""
    }

    var menuBarTimeText: String? {
        switch MenuBarDisplayResolver.presentation(
            mode: menuBarMode,
            isEnabled: isEnabled,
            systemIdentifier: systemIdentifier,
            savedIdentifiers: savedIdentifiers
        ) {
        case .icon:
            return nil
        case .time(let identifier):
            return formattedClockText(for: identifier)
        }
    }

    var menuBarIconName: String {
        isEnabled ? "clock.badge.checkmark" : "clock"
    }

    func localized(_ key: String) -> String {
        AppLocalization.string(key, language: appLanguage)
    }

    func displayName(for identifier: String) -> String {
        if let custom = customLabels[identifier]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return TimeZoneCatalogEntry(identifier: identifier).displayName(locale: appLanguage.locale)
    }

    func clockFace(for identifier: String) -> TimeZoneClockFace? {
        let systemTimeZone = TimeZone(identifier: systemIdentifier) ?? .current
        return TimeZoneClock.face(
            identifier: identifier,
            at: now,
            interfaceLanguage: appLanguage,
            systemTimeZone: systemTimeZone,
            format: timeDisplayFormat
        )
    }

    func isSaved(_ identifier: String) -> Bool {
        savedIdentifiers.contains(identifier)
    }

    func canRemove(_ identifier: String) -> Bool {
        !(isEnabled && identifier == homeIdentifier)
    }

    func refresh() {
        systemIdentifier = (try? system.currentTimeZoneIdentifier()) ?? TimeZone.current.identifier
        savedIdentifiers = store.savedIdentifiers
        homeIdentifier = store.homeIdentifier
        isEnabled = store.isEnabled
        menuBarMode = store.menuBarMode
        timeDisplayFormat = store.timeDisplayFormat
        appLanguage = store.appLanguage
        customLabels = store.customLabels
        now = Date()
    }

    func setTimeDisplayFormat(_ format: TimeDisplayFormat) {
        let secondsChanged = format.updatesEverySecond() != timeDisplayFormat.updatesEverySecond()
        store.timeDisplayFormat = format
        timeDisplayFormat = format
        now = Date()
        if secondsChanged {
            scheduleClockUpdate()
        }
    }

    func setAppLanguage(_ language: AppLanguage) {
        store.appLanguage = language
        appLanguage = language
    }

    func setCustomLabel(_ label: String, for identifier: String) {
        var labels = customLabels
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            labels.removeValue(forKey: identifier)
        } else {
            labels[identifier] = trimmed
        }
        store.customLabels = labels
        customLabels = labels
    }

    func add(_ identifier: String) {
        guard !isWorking else { return }
        errorMessage = nil

        do {
            try coordinator.add(identifier)
            searchText = ""
            refresh()
        } catch {
            errorMessage = readableMessage(for: error)
        }
    }

    func remove(_ identifier: String) {
        perform {
            try coordinator.remove(identifier)
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !isWorking else { return }
        coordinator.move(fromOffsets: source, toOffset: destination)
        refresh()
    }

    func apply(_ identifier: String) {
        perform {
            try coordinator.applySystemTimeZone(identifier)
        }
    }

    func restore() {
        perform {
            try coordinator.restoreHomeTimeZone()
        }
    }

    func pin(_ identifier: String) {
        guard !isWorking else { return }
        errorMessage = nil
        if case .pinned(let pinned) = menuBarMode, pinned == identifier {
            coordinator.setMenuBarMode(.automatic)
        } else {
            coordinator.setMenuBarMode(.pinned(identifier))
        }
        refresh()
    }

    func setMenuBarMode(_ mode: MenuBarDisplayMode) {
        guard !isWorking else { return }
        coordinator.setMenuBarMode(mode)
        refresh()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func perform(_ operation: () throws -> Void) {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil

        do {
            try operation()
            refresh()
        } catch {
            refresh()
            errorMessage = readableMessage(for: error)
        }

        isWorking = false
    }

    private func observeSystemChanges() {
        let names: [Notification.Name] = [
            .NSSystemTimeZoneDidChange,
            NSLocale.currentLocaleDidChangeNotification
        ]
        notificationObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }
    }

    private func scheduleClockUpdate() {
        clockTimer?.invalidate()
        if timeDisplayFormat.updatesEverySecond() {
            clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
            return
        }

        let delay = Self.delayUntilNextMinute(from: Date())
        clockTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.advanceClock()
            }
        }
    }

    private func advanceClock() {
        tick()
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        now = Date()
        if let current = try? system.currentTimeZoneIdentifier() {
            systemIdentifier = current
        }
    }

    private func formattedClockText(for identifier: String) -> String? {
        TimeZoneClock.menuBarText(
            identifier: identifier,
            at: now,
            format: timeDisplayFormat,
            interfaceLanguage: appLanguage
        )
    }

    private static func delayUntilNextMinute(from date: Date) -> TimeInterval {
        let remainder = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
        let delay = 60 - remainder
        return delay == 0 ? 60 : delay
    }

    private func readableMessage(for error: Error) -> String {
        guard let toolError = error as? TimeZoneToolError else {
            return error.localizedDescription
        }

        switch toolError {
        case .invalidTimeZoneIdentifier:
            return localized("That is not a valid time zone identifier.")
        case .missingOriginalTimeZone:
            return localized("No previously recorded time zone is available to restore.")
        case .unableToReadCurrentTimeZone:
            return localized("Could not read the current system time zone.")
        case .commandFailed(let output):
            return output.isEmpty ? localized("The system time zone command failed.") : output
        case .cannotRemoveHomeTimeZone:
            return localized("The home time zone can't be removed while the override is active.")
        }
    }
}
