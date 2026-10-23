import XCTest
@testable import TimeZoneCore

final class ClockRowTests: XCTestCase {
    // 2026-10-20 20:00 UTC: Los Angeles 13:00 on the 20th, Shanghai 04:00 on the 21st.
    private let date = utcDate(year: 2026, month: 10, day: 20, hour: 20)

    func testTitleUsesLocalizedCityNameUnlessRenamed() {
        let chinese = rows(["America/Los_Angeles", "Asia/Shanghai"], language: .simplifiedChinese)
        XCTAssertEqual(chinese.map(\.title), ["洛杉矶", "上海"])

        let english = rows(
            ["America/Los_Angeles", "Asia/Shanghai"],
            customLabels: ["Asia/Shanghai": "  Home  "],
            language: .english
        )
        XCTAssertEqual(english.map(\.title), ["Los Angeles", "Home"])
        XCTAssertEqual(english.map(\.cityName), ["Los Angeles", "Shanghai"])
        XCTAssertEqual(english.map(\.hasCustomLabel), [false, true])
    }

    func testBlankCustomLabelFallsBackToCity() {
        let row = rows(["Europe/London"], customLabels: ["Europe/London": "   "], language: .english)[0]
        XCTAssertEqual(row.title, "London")
        XCTAssertFalse(row.hasCustomLabel)
    }

    func testZonesWithoutACityUseTheZoneName() {
        let name = TimeZoneCatalogEntry(identifier: "Etc/UTC").localizedCityName(locale: Locale(identifier: "en"))
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.localizedCaseInsensitiveContains("unknown"))
    }

    func testDayOffsetAndDifferenceAreRelativeToTheSystemZone() {
        let fromLosAngeles = rows(["Asia/Shanghai", "America/Los_Angeles"], system: "America/Los_Angeles")
        XCTAssertEqual(fromLosAngeles.map(\.dayOffset), [1, 0])
        XCTAssertEqual(fromLosAngeles.map(\.secondsFromSystem), [15 * 3600, 0])
        XCTAssertEqual(fromLosAngeles.map(\.timeText), ["04:00", "13:00"])

        let fromShanghai = rows(["America/Los_Angeles"], system: "Asia/Shanghai")[0]
        XCTAssertEqual(fromShanghai.dayOffset, -1)
        XCTAssertEqual(fromShanghai.secondsFromSystem, -15 * 3600)
    }

    func testDayOffsetCanSpanTwoDays() {
        // UTC-12 is 23:30 on the 19th while Kiritimati (UTC+14) is 01:30 on the 21st.
        let late = utcDate(year: 2026, month: 10, day: 20, hour: 11, minute: 30)
        let row = ClockRowModel.rows(
            savedIdentifiers: ["Pacific/Kiritimati"],
            systemIdentifier: "Etc/GMT+12",
            homeIdentifier: nil,
            isEnabled: false,
            menuBarMode: .automatic,
            customLabels: [:],
            at: late
        )[0]
        XCTAssertEqual(row.dayOffset, 2)
        XCTAssertEqual(row.secondsFromSystem, 26 * 3600)
    }

    func testFractionalOffsetsKeepMinutes() {
        let row = rows(["Asia/Kolkata"], system: "Etc/UTC")[0]
        XCTAssertEqual(row.secondsFromSystem, 5 * 3600 + 30 * 60)
        XCTAssertEqual(row.utcOffsetText, "UTC+5:30")
    }

    func testRelativeHoursText() {
        XCTAssertEqual(TimeZoneClock.relativeHoursText(seconds: 15 * 3600), "+15")
        XCTAssertEqual(TimeZoneClock.relativeHoursText(seconds: -3 * 3600), "-3")
        XCTAssertEqual(TimeZoneClock.relativeHoursText(seconds: 5 * 3600 + 30 * 60), "+5:30")
        XCTAssertEqual(TimeZoneClock.relativeHoursText(seconds: -(9 * 3600 + 30 * 60)), "-9:30")
        XCTAssertEqual(TimeZoneClock.relativeHoursText(seconds: 45 * 60), "+0:45")
        XCTAssertEqual(TimeZoneClock.relativeHoursText(seconds: 0), "0")
    }

    func testDaytimeFollowsLocalHour() {
        let result = rows(["Asia/Shanghai", "America/Los_Angeles"])
        XCTAssertEqual(result.map(\.isDaytime), [false, true])

        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        XCTAssertFalse(TimeZoneClock.isDaytime(at: utcDate(year: 2026, month: 10, day: 20, hour: 21, minute: 59), in: shanghai))
        XCTAssertTrue(TimeZoneClock.isDaytime(at: utcDate(year: 2026, month: 10, day: 20, hour: 22), in: shanghai))
        XCTAssertTrue(TimeZoneClock.isDaytime(at: utcDate(year: 2026, month: 10, day: 21, hour: 9, minute: 59), in: shanghai))
        XCTAssertFalse(TimeZoneClock.isDaytime(at: utcDate(year: 2026, month: 10, day: 21, hour: 10), in: shanghai))
    }

    func testRolesDuringOverride() {
        let result = rows(
            ["Asia/Shanghai", "America/Los_Angeles", "Europe/London"],
            system: "America/Los_Angeles",
            home: "Asia/Shanghai",
            isEnabled: true,
            menuBarMode: .pinned("Europe/London")
        )

        XCTAssertEqual(result.map(\.isSystem), [false, true, false])
        XCTAssertEqual(result.map(\.isHome), [true, false, false])
        XCTAssertEqual(result.map(\.isPinned), [false, false, true])
        XCTAssertEqual(result.map(\.canRemove), [false, true, true])
    }

    func testHomeIsIgnoredWithoutOverride() {
        let result = rows(["Asia/Shanghai"], system: "Asia/Shanghai", home: "Asia/Shanghai", isEnabled: false)[0]
        XCTAssertTrue(result.isSystem)
        XCTAssertFalse(result.isHome)
        XCTAssertTrue(result.canRemove)
    }

    func testInvalidIdentifiersAreSkipped() {
        let result = rows(["Not/AZone", "Asia/Tokyo"])
        XCTAssertEqual(result.map(\.identifier), ["Asia/Tokyo"])
    }

    private func rows(
        _ identifiers: [String],
        system: String = "America/Los_Angeles",
        home: String? = nil,
        isEnabled: Bool = false,
        menuBarMode: MenuBarDisplayMode = .automatic,
        customLabels: [String: String] = [:],
        language: AppLanguage = .english
    ) -> [ClockRowModel] {
        ClockRowModel.rows(
            savedIdentifiers: identifiers,
            systemIdentifier: system,
            homeIdentifier: home,
            isEnabled: isEnabled,
            menuBarMode: menuBarMode,
            customLabels: customLabels,
            at: date,
            format: TimeDisplayFormat(preset: .timeOnly, showsSeconds: false),
            interfaceLanguage: language
        )
    }
}

private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}
