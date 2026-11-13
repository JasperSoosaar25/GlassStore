import XCTest
@testable import GlassStore

final class URLBuilderTests: XCTestCase {

    func testChartURL() throws {
        let url = try StorefrontService.chartURL(kind: .topFree, storefront: "us", limit: 25)
        XCTAssertEqual(url.absoluteString, "https://itunes.apple.com/us/rss/topfreeapplications/limit/25/json")
    }

    func testAllChartKindsBuildValidURLs() throws {
        for kind in ChartKind.allCases {
            let url = try StorefrontService.chartURL(kind: kind, storefront: "gb", limit: 10)
            XCTAssertTrue(url.absoluteString.hasPrefix("https://itunes.apple.com/gb/rss/"))
            XCTAssertTrue(url.absoluteString.hasSuffix("/limit/10/json"))
        }
    }

    func testSearchURLPercentEncodesTerms() throws {
        let url = try StorefrontService.searchURL(term: "photo editor", storefront: "us", limit: 25)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "itunes.apple.com")
        XCTAssertEqual(components.path, "/search")
        let items = components.queryItems ?? []
        XCTAssertTrue(items.contains { $0.name == "term" && $0.value == "photo editor" })
        XCTAssertTrue(items.contains { $0.name == "entity" && $0.value == "software" })
        XCTAssertTrue(items.contains { $0.name == "country" && $0.value == "us" })
    }

    func testLookupURL() throws {
        let url = try StorefrontService.lookupURL(id: 284882215, storefront: "ee")
        XCTAssertEqual(url.absoluteString, "https://itunes.apple.com/lookup?id=284882215&country=ee")
    }

    func testStorePageURL() {
        let url = StorefrontService.storePageURL(id: 284882215, storefront: "us")
        XCTAssertEqual(url?.absoluteString, "https://apps.apple.com/us/app/id284882215")
    }
}
