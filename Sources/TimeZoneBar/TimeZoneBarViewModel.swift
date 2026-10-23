import AppKit
import Foundation
import SwiftUI
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
    @Published private(set) var showsMenuBarIcon = true
    @Published private(set) var isWorking = false
    /// The row waiting on a system time zone change, while the authorization prompt is up.
    @Published private(set) var switchingIdentifier: String?
    /// Briefly set after adding, so the list can point out the new row.
    @Published private(set) var recentlyAddedIdentifier: String?
    @Published private(set) var now = Date()
    @Published var errorMessage: String?

    private let store: TimeZoneStateStoring
    private let system: SystemTimeZoneServicing
    private let coordinator: WorldClockCoordinator
    private var cachedPlaceIndex: (language: AppLanguage, index: TimeZonePlaceIndex)?
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
        // Build the add picker's index after launch so the first "Add" opens without a pause.
        DispatchQueue.main.async { [weak self] in
            _ = self?.placeIndex
        }
    }

    deinit {
        clockTimer?.invalidate()
        let observers = notificationObservers
        notificationObservers = []
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Every zone the add picker can offer, localized for the interface language.
    /// Building it formats a few hundred names, so it is kept until the language changes.
    var placeIndex: TimeZonePlaceIndex {
        if let cached = cachedPlaceIndex, cached.language == appLanguage {
            return cached.index
        }
        let index = TimeZonePlaceIndex(locale: appLanguage.locale)
        cachedPlaceIndex = (appLanguage, index)
        return index
    }

    /// The zone whose time is in the menu bar right now, or nil when only the icon shows.
    var menuBarIdentifier: String? {
        switch MenuBarDisplayResolver.presentation(
            mode: menuBarMode,
            isEnabled: isEnabled,
            systemIdentifier: systemIdentifier,
            savedIdentifiers: savedIdentifiers
        ) {
        case .icon:
            return nil
        case .time(let identifier):
            return identifier
        }
    }

    /// The zone the settings window renders format samples with, even while the menu bar shows only the icon.
    var previewIdentifier: String {
        menuBarIdentifier ?? savedIdentifiers.first ?? systemIdentifier
    }

    var menuBarTimeText: String? {
        menuBarIdentifier.flatMap(formattedClockText(for:))
    }

    var menuBarIconName: String {
        isEnabled ? "clock.badge.checkmark" : "clock"
    }

    /// Without a time the icon is all there is, so the preference only applies next to text.
    var menuBarShowsIcon: Bool {
        menuBarTimeText == nil || showsMenuBarIcon
    }

    func localized(_ key: String) -> String {
        AppLocalization.string(key, language: appLanguage)
    }

    func displayName(for identifier: String) -> String {
        if let custom = customLabels[identifier]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return TimeZoneCatalogEntry(identifier: identifier).localizedCityName(locale: appLanguage.locale)
    }

    var systemDisplayName: String {
        displayName(for: systemIdentifier)
    }

    var homeDisplayName: String? {
        homeIdentifier.map(displayName(for:))
    }

    var clockRows: [ClockRowModel] {
        ClockRowModel.rows(
            savedIdentifiers: savedIdentifiers,
            systemIdentifier: systemIdentifier,
            homeIdentifier: homeIdentifier,
            isEnabled: isEnabled,
            menuBarMode: menuBarMode,
            customLabels: customLabels,
            at: now,
            format: timeDisplayFormat,
            interfaceLanguage: appLanguage
        )
    }

    /// The time and offset a zone would show if it were added, for the add picker.
    func previewRow(for identifier: String) -> ClockRowModel? {
        ClockRowModel.rows(
            savedIdentifiers: [identifier],
            systemIdentifier: systemIdentifier,
            homeIdentifier: nil,
            isEnabled: false,
            menuBarMode: .automatic,
            customLabels: [:],
            at: now,
            format: timeDisplayFormat,
            interfaceLanguage: appLanguage
        ).first
    }

    func isSaved(_ identifier: String) -> Bool {
        savedIdentifiers.contains(identifier)
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
        showsMenuBarIcon = store.showsMenuBarIcon
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

    func setShowsMenuBarIcon(_ shows: Bool) {
        store.showsMenuBarIcon = shows
        showsMenuBarIcon = shows
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
            refresh()
            recentlyAddedIdentifier = identifier
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                if recentlyAddedIdentifier == identifier {
                    withAnimation(.easeOut(duration: 0.4)) {
                        recentlyAddedIdentifier = nil
                    }
                }
            }
        } catch {
            errorMessage = readableMessage(for: error)
        }
    }

    func remove(_ identifier: String) {
        // Removing the active system zone restores home first, which needs authorization.
        let restoring = isEnabled && identifier == systemIdentifier
        perform(switchingTo: restoring ? homeIdentifier : nil) { [coordinator] in
            try await coordinator.remove(identifier)
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !isWorking else { return }
        coordinator.move(fromOffsets: source, toOffset: destination)
        refresh()
    }

    func apply(_ identifier: String) {
        perform(switchingTo: identifier) { [coordinator] in
            try await coordinator.applySystemTimeZone(identifier)
        }
    }

    func restore() {
        perform(switchingTo: homeIdentifier) { [coordinator] in
            try await coordinator.restoreHomeTimeZone()
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

    /// Runs a change that may ask for administrator authorization. The popover keeps updating
    /// while the prompt is up; `target` is the row that shows progress meanwhile.
    private func perform(
        switchingTo target: String?,
        _ operation: @escaping @Sendable @MainActor () async throws -> Void
    ) {
        guard !isWorking else { return }

        isWorking = true
        switchingIdentifier = target
        errorMessage = nil

        Task {
            do {
                try await operation()
            } catch TimeZoneToolError.cancelled {
                // Dismissing the authorization prompt just leaves everything as it was.
            } catch {
                errorMessage = readableMessage(for: error)
            }
            withAnimation(.snappy(duration: 0.3)) {
                refresh()
                isWorking = false
                switchingIdentifier = nil
            }
        }
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
        case .cancelled:
            return localized("The administrator authorization was cancelled.")
        }
    }
}
