import XCTest
@testable import TimeZoneCore

final class ToggleCoordinatorTests: XCTestCase {
    func testEnableRecordsCurrentZoneAndSwitchesToTargetZone() throws {
        let store = InMemoryTimeZoneStore(targetIdentifier: "America/Los_Angeles")
        let system = FakeSystemTimeZone(currentIdentifier: "Asia/Shanghai")
        let coordinator = TimeZoneToggleCoordinator(store: store, system: system)

        try coordinator.setEnabled(true)

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.originalIdentifier, "Asia/Shanghai")
        XCTAssertEqual(system.setCalls, ["America/Los_Angeles"])
    }

    func testDisableRestoresRecordedOriginalZoneAndClearsOverrideState() throws {
        let store = InMemoryTimeZoneStore(
            targetIdentifier: "Europe/London",
            originalIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(currentIdentifier: "Europe/London")
        let coordinator = TimeZoneToggleCoordinator(store: store, system: system)

        try coordinator.setEnabled(false)

        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.originalIdentifier)
        XCTAssertEqual(system.setCalls, ["Asia/Shanghai"])
    }

    func testChangingTargetWhileEnabledKeepsOriginalZoneAndAppliesNewTarget() throws {
        let store = InMemoryTimeZoneStore(
            targetIdentifier: "America/Los_Angeles",
            originalIdentifier: "Asia/Shanghai",
            isEnabled: true
        )
        let system = FakeSystemTimeZone(currentIdentifier: "America/Los_Angeles")
        let coordinator = TimeZoneToggleCoordinator(store: store, system: system)

        try coordinator.setTargetIdentifier("Asia/Tokyo")

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.originalIdentifier, "Asia/Shanghai")
        XCTAssertEqual(store.targetIdentifier, "Asia/Tokyo")
        XCTAssertEqual(system.setCalls, ["Asia/Tokyo"])
    }
}

private final class FakeSystemTimeZone: SystemTimeZoneServicing {
    var currentIdentifier: String
    private(set) var setCalls: [String] = []

    init(currentIdentifier: String) {
        self.currentIdentifier = currentIdentifier
    }

    func currentTimeZoneIdentifier() throws -> String {
        currentIdentifier
    }

    func setTimeZone(identifier: String) throws {
        setCalls.append(identifier)
        currentIdentifier = identifier
    }
}
