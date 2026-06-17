import AppKit
import Foundation
import TimeZoneCore

@MainActor
final class TimeZoneBarViewModel: ObservableObject {
    @Published private(set) var currentIdentifier = "Unknown"
    @Published private(set) var originalIdentifier: String?
    @Published private(set) var targetIdentifier: String
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isWorking = false
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let store: TimeZoneStateStoring
    private let system: SystemTimeZoneServicing
    private let coordinator: TimeZoneToggleCoordinator
    private let catalog = TimeZoneCatalog()

    init(
        store: TimeZoneStateStoring = UserDefaultsTimeZoneStore(),
        system: SystemTimeZoneServicing = LocalSystemTimeZoneService()
    ) {
        self.store = store
        self.system = system
        self.coordinator = TimeZoneToggleCoordinator(store: store, system: system)
        self.targetIdentifier = store.targetIdentifier
        self.originalIdentifier = store.originalIdentifier
        self.isEnabled = store.isEnabled
        refreshCurrentTimeZone()
    }

    var filteredEntries: [TimeZoneCatalogEntry] {
        Array(catalog.search(searchText).prefix(80))
    }

    func displayName(for identifier: String) -> String {
        TimeZoneCatalogEntry(identifier: identifier).displayName()
    }

    func refreshCurrentTimeZone() {
        currentIdentifier = (try? system.currentTimeZoneIdentifier()) ?? TimeZone.current.identifier
        targetIdentifier = store.targetIdentifier
        originalIdentifier = store.originalIdentifier
        isEnabled = store.isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil

        do {
            try coordinator.setEnabled(enabled)
            refreshCurrentTimeZone()
        } catch {
            refreshCurrentTimeZone()
            errorMessage = readableMessage(for: error)
        }

        isWorking = false
    }

    func selectTarget(_ identifier: String) {
        guard !isWorking, identifier != targetIdentifier else { return }

        isWorking = true
        errorMessage = nil

        do {
            try coordinator.setTargetIdentifier(identifier)
            refreshCurrentTimeZone()
        } catch {
            refreshCurrentTimeZone()
            errorMessage = readableMessage(for: error)
        }

        isWorking = false
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func readableMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
