import XCTest
@testable import GlassStore

final class SearchParsingTests: XCTestCase {

    private func loadFixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: SearchParsingTests.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "json"),
            "Fixture \(name).json missing from the test bundle"
        )
        return try Data(contentsOf: url)
    }

    func testSearchResponseMapsToItems() throws {
        let data = try loadFixture("fixture_search")
        let payload = try JSONDecoder().decode(ITunesResponse.self, from: data)
        XCTAssertGreaterThanOrEqual(payload.results.count, 2)

        let items = payload.results.compactMap { StorefrontService.item(fromSearch: $0) }
        XCTAssertEqual(items.count, payload.results.count)

        let first = try XCTUnwrap(items.first)
        XCTAssertNotNil(first.iconURL)
        XCTAssertNotNil(first.rating)
        XCTAssertNotNil(first.ratingCount)
        XCTAssertFalse(first.name.isEmpty)
    }

    func testLookupFixtureMapsDetailFields() throws {
        let data = try loadFixture("fixture_lookup")
        let payload = try JSONDecoder().decode(ITunesResponse.self, from: data)
        let result = try XCTUnwrap(payload.results.first)

        let item = try XCTUnwrap(StorefrontService.item(fromSearch: result))
        XCTAssertEqual(item.name, "Facebook")
        XCTAssertEqual(item.id, 284882215)
        XCTAssertTrue(item.isFree)
        XCTAssertEqual(item.priceLabel, "Free")
        XCTAssertFalse(item.screenshots.isEmpty, "lookup carries iPhone screenshots")
        XCTAssertNotNil(item.version)
        XCTAssertNotNil(item.minimumOSVersion)
        XCTAssertNotNil(item.fileSizeBytes)
        XCTAssertNotNil(item.contentAdvisoryRating)
        XCTAssertNotNil(item.heroArtURL, "hero art falls back to the first screenshot")
    }
}
