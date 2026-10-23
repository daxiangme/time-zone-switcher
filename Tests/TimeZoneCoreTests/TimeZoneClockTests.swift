import XCTest
@testable import TimeZoneCore

final class TimeZoneClockTests: XCTestCase {
    func testOffsetTextKeepsFractionalHours() {
        XCTAssertEqual(TimeZoneClock.offsetText(secondsFromGMT: 5 * 3600 + 30 * 60), "UTC+5:30")
        XCTAssertEqual(TimeZoneClock.offsetText(secondsFromGMT: 5 * 3600 + 45 * 60), "UTC+5:45")
        XCTAssertEqual(TimeZoneClock.offsetText(secondsFromGMT: -7 * 3600), "UTC-7")
        XCTAssertEqual(TimeZoneClock.offsetText(secondsFromGMT: -(9 * 3600 + 30 * 60)), "UTC-9:30")
        XCTAssertEqual(TimeZoneClock.offsetText(secondsFromGMT: 0), "UTC+0")
    }

    func testClockUsesEachZoneInsteadOfTheSystemZone() {
        let date = utcDate(year: 2026, month: 10, day: 20, hour: 20)
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!

        let shanghaiFromLosAngeles = TimeZoneClock.face(
            identifier: "Asia/Shanghai",
            at: date,
            systemTimeZone: losAngeles
        )
        let shanghaiFromShanghai = TimeZoneClock.face(
            identifier: "Asia/Shanghai",
            at: date,
            systemTimeZone: shanghai
        )
        let losAngelesFace = TimeZoneClock.face(
            identifier: "America/Los_Angeles",
            at: date,
            systemTimeZone: losAngeles
        )

        XCTAssertEqual(shanghaiFromLosAngeles?.timeText, "04:00")
        XCTAssertEqual(shanghaiFromLosAngeles?.timeText, shanghaiFromShanghai?.timeText)
        XCTAssertEqual(shanghaiFromLosAngeles?.offsetText, "UTC+8")
        XCTAssertNotNil(shanghaiFromLosAngeles?.dateText)
        XCTAssertNil(shanghaiFromShanghai?.dateText)
        XCTAssertEqual(losAngelesFace?.timeText, "13:00")
        XCTAssertEqual(losAngelesFace?.abbreviation, "PDT")
        XCTAssertEqual(losAngelesFace?.offsetText, "UTC-7")
        XCTAssertNil(losAngelesFace?.dateText)
    }

    func testFractionalZonesExposeOffsetAndLocalTime() {
        let date = utcDate(year: 2026, month: 7, day: 15, hour: 12)
        let kolkata = TimeZoneClock.face(
            identifier: "Asia/Kolkata",
            at: date,
            systemTimeZone: TimeZone(identifier: "Etc/UTC")!
        )
        let kathmandu = TimeZoneClock.face(
            identifier: "Asia/Kathmandu",
            at: date,
            systemTimeZone: TimeZone(identifier: "Etc/UTC")!
        )

        XCTAssertEqual(kolkata?.offsetText, "UTC+5:30")
        XCTAssertEqual(kolkata?.timeText, "17:30")
        XCTAssertEqual(kathmandu?.offsetText, "UTC+5:45")
        XCTAssertEqual(kathmandu?.timeText, "17:45")
    }

    func testDefaultMenuBarTextUsesAbbreviationAndTwentyFourHourTime() {
        let date = utcDate(year: 2026, month: 10, day: 20, hour: 20)
        let text = TimeZoneClock.menuBarText(identifier: "America/Los_Angeles", at: date)

        XCTAssertEqual(normalize(text ?? ""), "PDT 13:00")
    }

    func testSecondsAreInsertedWithoutTouchingMonthNames() {
        XCTAssertEqual(TimeDisplayFormat.applyingSeconds("HH:mm", showsSeconds: true), "HH:mm:ss")
        XCTAssertEqual(TimeDisplayFormat.applyingSeconds("z HH:mm", showsSeconds: true), "z HH:mm:ss")
        XCTAssertEqual(
            TimeDisplayFormat.applyingSeconds("E, MMM d, h:mm a", showsSeconds: true),
            "E, MMM d, h:mm:ss a"
        )
        XCTAssertEqual(TimeDisplayFormat.applyingSeconds("HH:mm:ss", showsSeconds: true), "HH:mm:ss")

        let date = utcDate(year: 2026, month: 10, day: 20, hour: 20, second: 7)
        let format = TimeDisplayFormat(preset: .abbreviationAndTime, showsSeconds: true)
        XCTAssertEqual(
            normalize(TimeZoneClock.menuBarText(identifier: "America/Los_Angeles", at: date, format: format) ?? ""),
            "PDT 13:00:07"
        )
    }

    func testChineseDatePresetIgnoresInterfaceLanguage() {
        let date = utcDate(year: 2026, month: 10, day: 20, hour: 20)
        let format = TimeDisplayFormat(preset: .chineseDateTime, showsSeconds: false)
        let text = normalize(
            TimeZoneClock.menuBarText(
                identifier: "America/Los_Angeles",
                at: date,
                format: format,
                interfaceLanguage: .english
            ) ?? ""
        )

        XCTAssertTrue(text.contains("10月20日"))
        XCTAssertTrue(text.contains("下午"))
        XCTAssertTrue(text.contains("1:00"))
    }

    func testLegacyTwelveHourTimeOnlyBecomesCustomPattern() {
        let format = TimeDisplayFormat.migratedFromLegacy(
            content: "time",
            hourCycle: "twelve",
            showsSeconds: true
        )

        XCTAssertEqual(format.preset, .custom)
        XCTAssertEqual(format.customPattern, "h:mm a")
        XCTAssertTrue(format.showsSeconds)
        XCTAssertEqual(format.pattern(), "h:mm:ss a")
    }

    func testMissingAbbreviationFallsBackToOffset() {
        XCTAssertEqual(TimeZoneClock.abbreviationText(nil, offsetText: "UTC+8"), "UTC+8")
        XCTAssertEqual(TimeZoneClock.abbreviationText("", offsetText: "UTC+5:30"), "UTC+5:30")
        XCTAssertEqual(TimeZoneClock.abbreviationText("PDT", offsetText: "UTC-7"), "PDT")
    }

    func testInvalidIdentifierHasNoClockFace() {
        XCTAssertNil(
            TimeZoneClock.face(
                identifier: "Not/AZone",
                at: Date(),
                systemTimeZone: .current
            )
        )
    }

    private func utcDate(year: Int, month: Int, day: Int, hour: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.second = second
        return components.date!
    }

    private func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{202f}", with: " ")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
