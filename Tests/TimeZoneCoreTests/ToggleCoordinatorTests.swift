import XCTest
@testable import TimeZoneCore

final class WorldClockCoordinatorTests: XCTestCase {
    func testAddIgnoresDuplicateAndPreservesOrder() throws {
        let store = InMemoryTimeZoneStore()
        let coordinator = WorldClockCoordinator(store: store, system: FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai"))

        try coordinator.add("America/Los_Angeles")
        try coordinator.add("Asia/Shanghai")
        try coordinator.add("America/Los_Angeles")

        XCTAssertEqual(store.savedIdentifiers, ["America/Los_Angeles", "Asia/Shanghai"])
    }

    func testAddRejectsInvalidIdentifier() {
        let store = InMemoryTimeZoneStore()
        let coordinator = WorldClockCoordinator(store: store, system: FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai"))

        XCTAssertThrowsError(try coordinator.add("Not/AZone")) { error in
            XCTAssertEqual(error as? TimeZoneToolError, .invalidTimeZoneIdentifier("Not/AZone"))
        }
        XCTAssertTrue(store.savedIdentifiers.isEmpty)
    }

    func testFirstApplyRecordsHomeAndInsertsItAtFront() throws {
        let store = InMemoryTimeZoneStore(savedIdentifiers: ["America/Los_Angeles"])
        let system = FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.applySystemTimeZone("America/Los_Angeles")

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.homeIdentifier, "Asia/Shanghai")
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertEqual(system.setCalls, ["America/Los_Angeles"])
    }

    func testFirstApplyKeepsExistingHomePosition() throws {
        let store = InMemoryTimeZoneStore(savedIdentifiers: ["America/Los_Angeles", "Asia/Shanghai"])
        let system = FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.applySystemTimeZone("America/Los_Angeles")

        XCTAssertEqual(store.homeIdentifier, "Asia/Shanghai")
        XCTAssertEqual(store.savedIdentifiers, ["America/Los_Angeles", "Asia/Shanghai"])
    }

    func testSwitchingAgainKeepsHomeRecord() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles", "Asia/Tokyo"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.applySystemTimeZone("Asia/Tokyo")

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.homeIdentifier, "Asia/Shanghai")
        XCTAssertEqual(system.currentIdentifier, "Asia/Tokyo")
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles", "Asia/Tokyo"])
    }

    func testRestoreReturnsHomeAndKeepsList() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.restoreHomeTimeZone()

        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.homeIdentifier)
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertEqual(system.setCalls, ["Asia/Shanghai"])
    }

    func testApplyingHomeWhileEnabledRestores() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.applySystemTimeZone("Asia/Shanghai")

        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.homeIdentifier)
        XCTAssertEqual(system.currentIdentifier, "Asia/Shanghai")
    }

    func testApplyingCurrentSystemZoneDoesNotEnableOverride() throws {
        let store = InMemoryTimeZoneStore(savedIdentifiers: ["America/Los_Angeles"])
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.applySystemTimeZone("America/Los_Angeles")

        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.homeIdentifier)
        XCTAssertTrue(system.setCalls.isEmpty)
    }

    func testFailedApplyDoesNotRecordOverride() {
        let store = InMemoryTimeZoneStore(savedIdentifiers: ["America/Los_Angeles"])
        let system = FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai", failure: TimeZoneToolError.commandFailed("cancelled"))
        let coordinator = WorldClockCoordinator(store: store, system: system)

        XCTAssertThrowsError(try coordinator.applySystemTimeZone("America/Los_Angeles"))
        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.homeIdentifier)
        XCTAssertEqual(store.savedIdentifiers, ["America/Los_Angeles"])
        XCTAssertEqual(system.currentIdentifier, "Asia/Shanghai")
    }

    func testCannotRemoveHomeWhileOverrideIsActive() {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        XCTAssertThrowsError(try coordinator.remove("Asia/Shanghai")) { error in
            XCTAssertEqual(error as? TimeZoneToolError, .cannotRemoveHomeTimeZone)
        }
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertTrue(system.setCalls.isEmpty)
        XCTAssertTrue(store.isEnabled)
    }

    func testRemovingActiveSystemZoneRestoresBeforeDeleting() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true,
            menuBarMode: .pinned("America/Los_Angeles")
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.remove("America/Los_Angeles")

        XCTAssertEqual(system.setCalls, ["Asia/Shanghai"])
        XCTAssertEqual(system.currentIdentifier, "Asia/Shanghai")
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai"])
        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.homeIdentifier)
        XCTAssertEqual(store.menuBarMode, .automatic)
    }

    func testFailedRemovalOfSystemZoneKeepsList() {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(
            currentIdentifier: "America/Los_Angeles",
            failure: TimeZoneToolError.commandFailed("cancelled")
        )
        let coordinator = WorldClockCoordinator(store: store, system: system)

        XCTAssertThrowsError(try coordinator.remove("America/Los_Angeles"))
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.homeIdentifier, "Asia/Shanghai")
        XCTAssertEqual(system.currentIdentifier, "America/Los_Angeles")
    }

    func testRemovingPinnedZoneClearsPinWithoutChangingSystemZone() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles", "Asia/Tokyo"],
            homeIdentifier: "Asia/Shanghai",
            isEnabled: true,
            menuBarMode: .pinned("Asia/Tokyo")
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = WorldClockCoordinator(store: store, system: system)

        try coordinator.remove("Asia/Tokyo")

        XCTAssertTrue(system.setCalls.isEmpty)
        XCTAssertEqual(system.currentIdentifier, "America/Los_Angeles")
        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertEqual(store.menuBarMode, .automatic)
        XCTAssertTrue(store.isEnabled)
    }

    func testRemovingZoneClearsItsCustomLabel() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Tokyo"],
            customLabels: ["Asia/Tokyo": "公司"]
        )
        let coordinator = WorldClockCoordinator(store: store, system: FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai"))

        try coordinator.remove("Asia/Tokyo")

        XCTAssertNil(store.customLabels["Asia/Tokyo"])
    }

    func testRemovingLastZoneReturnsMenuBarToAutomatic() throws {
        let store = InMemoryTimeZoneStore(
            savedIdentifiers: ["Asia/Tokyo"],
            menuBarMode: .pinned("Asia/Tokyo")
        )
        let coordinator = WorldClockCoordinator(store: store, system: FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai"))

        try coordinator.remove("Asia/Tokyo")

        XCTAssertTrue(store.savedIdentifiers.isEmpty)
        XCTAssertEqual(store.menuBarMode, .automatic)
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: store.menuBarMode,
                isEnabled: store.isEnabled,
                systemIdentifier: "Asia/Shanghai",
                savedIdentifiers: store.savedIdentifiers
            ),
            .icon(overrideActive: false)
        )
    }

    func testMoveReordersSavedZones() {
        let store = InMemoryTimeZoneStore(savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles", "Asia/Tokyo"])
        let coordinator = WorldClockCoordinator(store: store, system: FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai"))

        coordinator.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        XCTAssertEqual(store.savedIdentifiers, ["America/Los_Angeles", "Asia/Tokyo", "Asia/Shanghai"])
    }

    func testPinIsIgnoredWhenZoneIsNotSaved() {
        let store = InMemoryTimeZoneStore(savedIdentifiers: ["Asia/Shanghai"], menuBarMode: .automatic)
        let coordinator = WorldClockCoordinator(store: store, system: FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai"))

        coordinator.setMenuBarMode(.pinned("America/Los_Angeles"))

        XCTAssertEqual(store.menuBarMode, .automatic)
    }

    func testMenuBarPresentation() {
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: .automatic,
                isEnabled: false,
                systemIdentifier: "Asia/Shanghai",
                savedIdentifiers: ["Asia/Shanghai"]
            ),
            .icon(overrideActive: false)
        )
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: .automatic,
                isEnabled: true,
                systemIdentifier: "America/Los_Angeles",
                savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"]
            ),
            .time("America/Los_Angeles")
        )
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: .pinned("Asia/Shanghai"),
                isEnabled: false,
                systemIdentifier: "America/Los_Angeles",
                savedIdentifiers: ["Asia/Shanghai", "America/Los_Angeles"]
            ),
            .time("Asia/Shanghai")
        )
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: .pinned("Europe/London"),
                isEnabled: true,
                systemIdentifier: "America/Los_Angeles",
                savedIdentifiers: ["America/Los_Angeles"]
            ),
            .time("America/Los_Angeles")
        )
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: .icon,
                isEnabled: true,
                systemIdentifier: "America/Los_Angeles",
                savedIdentifiers: ["America/Los_Angeles"]
            ),
            .icon(overrideActive: true)
        )
        XCTAssertEqual(
            MenuBarDisplayResolver.presentation(
                mode: .automatic,
                isEnabled: false,
                systemIdentifier: "Asia/Shanghai",
                savedIdentifiers: []
            ),
            .icon(overrideActive: false)
        )
    }
}

final class UserDefaultsTimeZoneStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TimeZoneCoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshStoreStartsEmpty() {
        let store = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(store.savedIdentifiers, [])
        XCTAssertNil(store.homeIdentifier)
        XCTAssertFalse(store.isEnabled)
        XCTAssertEqual(store.menuBarMode, .automatic)
        XCTAssertEqual(store.timeDisplayFormat, .standard)
        XCTAssertEqual(store.appLanguage, .system)
        XCTAssertTrue(store.customLabels.isEmpty)
    }

    func testTimeDisplayFormatRoundTrips() {
        let store = UserDefaultsTimeZoneStore(defaults: defaults)
        store.timeDisplayFormat = TimeDisplayFormat(
            preset: .custom,
            showsSeconds: true,
            customPattern: "HH:mm"
        )
        store.appLanguage = .english
        store.customLabels = ["Asia/Shanghai": "家里"]

        let reloaded = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(reloaded.timeDisplayFormat.preset, .custom)
        XCTAssertTrue(reloaded.timeDisplayFormat.showsSeconds)
        XCTAssertEqual(reloaded.timeDisplayFormat.customPattern, "HH:mm")
        XCTAssertEqual(reloaded.appLanguage, .english)
        XCTAssertEqual(reloaded.customLabels["Asia/Shanghai"], "家里")
    }

    func testLegacyFormatMigratesUntilAPresetIsSaved() {
        defaults.set("time", forKey: "clockContent")
        defaults.set("twelve", forKey: "hourCycle")
        defaults.set(true, forKey: "showsSeconds")

        let store = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(store.timeDisplayFormat.preset, .custom)
        XCTAssertEqual(store.timeDisplayFormat.customPattern, "h:mm a")
        XCTAssertTrue(store.timeDisplayFormat.showsSeconds)
    }

    func testLegacyTargetIsMigratedWithoutEnablingOverride() {
        defaults.set("Europe/London", forKey: "targetIdentifier")

        let store = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(store.savedIdentifiers, ["Europe/London"])
        XCTAssertNil(store.homeIdentifier)
        XCTAssertFalse(store.isEnabled)
    }

    func testLegacyOverrideMigratesHomeAndTarget() {
        defaults.set("America/Los_Angeles", forKey: "targetIdentifier")
        defaults.set("Asia/Shanghai", forKey: "originalIdentifier")
        defaults.set(true, forKey: "isEnabled")

        let store = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(store.savedIdentifiers, ["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertEqual(store.homeIdentifier, "Asia/Shanghai")
        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.menuBarMode, .automatic)
    }

    func testExistingSavedListIsNotReplacedByLegacyTarget() {
        defaults.set(["Europe/Paris"], forKey: "savedIdentifiers")
        defaults.set("America/Los_Angeles", forKey: "targetIdentifier")

        let store = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(store.savedIdentifiers, ["Europe/Paris"])
    }

    func testMenuBarPinRoundTrips() {
        let store = UserDefaultsTimeZoneStore(defaults: defaults)
        store.savedIdentifiers = ["Asia/Shanghai"]
        store.menuBarMode = .pinned("Asia/Shanghai")

        let reloaded = UserDefaultsTimeZoneStore(defaults: defaults)

        XCTAssertEqual(reloaded.menuBarMode, .pinned("Asia/Shanghai"))
    }
}

private final class FakeSystemTimeZone: SystemTimeZoneServicing {
    var currentIdentifier: String
    var failure: Error?
    private(set) var setCalls: [String] = []

    init(currentIdentifier: String, failure: Error? = nil) {
        self.currentIdentifier = currentIdentifier
        self.failure = failure
    }

    func currentTimeZoneIdentifier() throws -> String {
        currentIdentifier
    }

    func setTimeZone(identifier: String) throws {
        if let failure {
            throw failure
        }
        setCalls.append(identifier)
        currentIdentifier = identifier
    }
}
