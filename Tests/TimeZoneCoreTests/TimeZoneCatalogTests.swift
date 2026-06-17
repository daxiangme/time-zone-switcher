import XCTest
@testable import TimeZoneCore

final class TimeZoneCatalogTests: XCTestCase {
    func testSearchMatchesCityAndRegionCaseInsensitively() {
        let catalog = TimeZoneCatalog(identifiers: [
            "Asia/Shanghai",
            "America/Los_Angeles",
            "Europe/London"
        ])

        XCTAssertEqual(catalog.search("los").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(catalog.search("asia").map(\.identifier), ["Asia/Shanghai"])
        XCTAssertEqual(catalog.search("LONDON").map(\.identifier), ["Europe/London"])
    }

    func testSearchWithEmptyQueryReturnsSortedZones() {
        let catalog = TimeZoneCatalog(identifiers: [
            "Europe/London",
            "Asia/Shanghai",
            "America/Los_Angeles"
        ])

        XCTAssertEqual(
            catalog.search("").map(\.identifier),
            ["America/Los_Angeles", "Asia/Shanghai", "Europe/London"]
        )
    }

    func testEntryDisplayNameUsesRequestedLocale() {
        let entry = TimeZoneCatalogEntry(identifier: "America/Los_Angeles")

        XCTAssertTrue(entry.displayName(locale: Locale(identifier: "zh_Hans_CN")).contains("太平洋"))
        XCTAssertEqual(entry.displayName(locale: Locale(identifier: "en_US")), "Pacific Time")
    }

    func testSearchMatchesLocalizedDisplayName() {
        let catalog = TimeZoneCatalog(
            identifiers: ["America/Los_Angeles", "Asia/Shanghai", "Europe/London"],
            locale: Locale(identifier: "zh_Hans_CN")
        )

        XCTAssertEqual(catalog.search("太平洋").map(\.identifier), ["America/Los_Angeles"])
    }

    func testPreferredDisplayLocaleUsesFirstAppleLanguageIdentifier() {
        let locale = TimeZoneDisplayLocale.preferred(from: ["zh-Hans-CN", "en-CN"])

        XCTAssertTrue(
            TimeZoneCatalogEntry(identifier: "America/Los_Angeles")
                .displayName(locale: locale)
                .contains("太平洋")
        )
    }
}
