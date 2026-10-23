import XCTest
@testable import TimeZoneCore

final class TimeZoneCatalogTests: XCTestCase {
    private let chinese = Locale(identifier: "zh_Hans_CN")
    private let english = Locale(identifier: "en_US")
    private let codes = [
        "Asia/Shanghai": "CN",
        "America/Los_Angeles": "US",
        "America/New_York": "US",
        "Europe/London": "GB",
        "Asia/Tokyo": "JP"
    ]

    func testSearchMatchesCityAndRegionCaseInsensitively() {
        let index = TimeZonePlaceIndex(
            identifiers: ["Asia/Shanghai", "America/Los_Angeles", "Europe/London"],
            locale: english,
            countryCodes: codes
        )

        XCTAssertEqual(index.search("los").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(index.search("los angeles").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(index.search("asia").map(\.identifier), ["Asia/Shanghai"])
        XCTAssertEqual(index.search("LONDON").map(\.identifier), ["Europe/London"])
    }

    func testEmptyQueryListsEveryPlaceByAreaThenCity() {
        let index = TimeZonePlaceIndex(
            identifiers: ["Europe/London", "America/New_York", "Asia/Tokyo", "America/Los_Angeles", "Asia/Shanghai", "GMT"],
            locale: english,
            countryCodes: codes
        )

        XCTAssertEqual(
            index.search("").map(\.identifier),
            ["Asia/Shanghai", "Asia/Tokyo", "Europe/London", "America/Los_Angeles", "America/New_York", "GMT"]
        )
        XCTAssertEqual(index.places.map(\.area), [.asia, .asia, .europe, .america, .america, .other])
    }

    func testPlacesCarryLocalizedCityCountryAndZoneName() {
        let index = TimeZonePlaceIndex(identifiers: ["America/Los_Angeles"], locale: chinese, countryCodes: codes)
        let place = index.place(for: "America/Los_Angeles")

        XCTAssertEqual(place?.city, "洛杉矶")
        XCTAssertEqual(place?.country, "美国")
        XCTAssertEqual(place?.zoneName.contains("太平洋"), true)
    }

    func testChineseSearchMatchesNamesPinyinAndInitials() {
        let index = TimeZonePlaceIndex(
            identifiers: ["Asia/Shanghai", "America/Los_Angeles", "Europe/London", "Asia/Tokyo"],
            locale: chinese,
            countryCodes: codes
        )

        XCTAssertEqual(index.search("洛杉").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(index.search("luoshan").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(index.search("lsj").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(index.search("dongjing").map(\.identifier), ["Asia/Tokyo"])
        XCTAssertEqual(index.search("太平洋").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(index.search("Los Angeles").map(\.identifier), ["America/Los_Angeles"])
    }

    func testCountryMatchesRankAfterCityMatches() {
        let index = TimeZonePlaceIndex(
            identifiers: ["America/New_York", "America/Los_Angeles", "Europe/London"],
            locale: english,
            countryCodes: codes
        )

        XCTAssertEqual(index.search("united states").map(\.identifier), ["America/Los_Angeles", "America/New_York"])
        // "London" as a city beats the United Kingdom match.
        XCTAssertEqual(index.search("lon").first?.identifier, "Europe/London")

        let japan = TimeZonePlaceIndex(identifiers: ["Asia/Tokyo"], locale: chinese, countryCodes: codes)
        XCTAssertEqual(japan.search("日本").map(\.identifier), ["Asia/Tokyo"])
        XCTAssertEqual(japan.search("japan").map(\.identifier), ["Asia/Tokyo"])
    }

    func testCityPrefixOutranksSubstring() {
        let index = TimeZonePlaceIndex(
            identifiers: ["America/Port_of_Spain", "Europe/Paris"],
            locale: english,
            countryCodes: [:]
        )

        // "pa" starts "Paris" but only appears inside "Port of Spain", even though Port of Spain sorts first.
        XCTAssertEqual(index.search("pa").map(\.identifier), ["Europe/Paris", "America/Port_of_Spain"])
    }

    func testGMTIsFoundAsUTC() {
        let index = TimeZonePlaceIndex(identifiers: ["GMT", "Europe/London"], locale: english, countryCodes: codes)
        XCTAssertEqual(index.search("utc").map(\.identifier), ["GMT"])
        XCTAssertEqual(index.place(for: "GMT")?.area, .other)
    }

    func testInvalidIdentifiersAreDropped() {
        let index = TimeZonePlaceIndex(identifiers: ["Not/AZone", "Asia/Tokyo"], locale: english, countryCodes: codes)
        XCTAssertEqual(index.places.map(\.identifier), ["Asia/Tokyo"])
    }

    func testZoneTabParsingSkipsCommentsAndKeepsCountryCodes() {
        let text = """
        # comment
        CN\t+3114+12128\tAsia/Shanghai\tBeijing Time
        US\t+340308-1181434\tAmerica/Los_Angeles\tPacific
        broken line
        """
        XCTAssertEqual(ZoneTab.parse(text), ["Asia/Shanghai": "CN", "America/Los_Angeles": "US"])
    }

    func testSystemZoneTabUsesCanonicalIdentifiers() throws {
        try XCTSkipIf(ZoneTab.countryCodes.isEmpty, "zone.tab is not available")
        let identifiers = Set(ZoneTab.identifiers)
        XCTAssertTrue(identifiers.contains("Asia/Kolkata"))
        XCTAssertTrue(identifiers.contains("GMT"))
        XCTAssertFalse(identifiers.contains("Asia/Calcutta"))
        XCTAssertFalse(identifiers.contains("Asia/Chongqing"))
    }

    func testEntryDisplayNameUsesRequestedLocale() {
        let entry = TimeZoneCatalogEntry(identifier: "America/Los_Angeles")

        XCTAssertTrue(entry.displayName(locale: chinese).contains("太平洋"))
        XCTAssertEqual(entry.displayName(locale: english), "Pacific Time")
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
