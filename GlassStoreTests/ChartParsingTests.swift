import XCTest
@testable import GlassStore

/// Decoding tests for the legacy chart feeds, using fixtures captured from the
/// live endpoints (see docs/RESEARCH.md). Trimming lives in the fixtures
/// themselves; every test pins the exact mapping the UI depends on.
final class ChartParsingTests: XCTestCase {

    private func loadFixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: ChartParsingTests.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "json"),
            "Fixture \(name).json missing from the test bundle"
        )
        return try Data(contentsOf: url)
    }

    func testTopFreeFeedDecodesAndMaps() throws {
        let data = try loadFixture("fixture_topfree")
        let feed = try JSONDecoder().decode(LegacyChartFeed.self, from: data)
        let entries = feed.feed?.entry?.entries ?? []
        XCTAssertGreaterThanOrEqual(entries.count, 2, "trimmed fixture keeps at least 2 entries")

        let items = entries.compactMap { StorefrontService.item(fromChart: $0) }
        XCTAssertEqual(items.count, entries.count, "every entry maps to a StoreItem")

        let first = try XCTUnwrap(items.first)
        XCTAssertFalse(first.name.isEmpty)
        XCTAssertFalse(first.artistName.isEmpty)
        XCTAssertNotNil(first.id)
        XCTAssertNotNil(first.iconURL)
        XCTAssertNotNil(first.storeURL)
        XCTAssertTrue(first.id > 0)
    }

    func testIconUpscaleRewritesTail() throws {
        // A real chart icon URL shape.
        let raw = try XCTUnwrap(URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/aa/bb/cc/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/100x100bb.png"))
        let upscaled = StorefrontService.upscaledIconURL(raw)
        XCTAssertTrue(upscaled.path.hasSuffix("/512x512bb.png"), "got \(upscaled.path)")

        // Already-large and non-matching URLs pass through untouched.
        let already = try XCTUnwrap(URL(string: "https://is1-ssl.mzstatic.com/image/thumb/x/512x512bb.jpg"))
        XCTAssertEqual(StorefrontService.upscaledIconURL(already), already)
        let odd = try XCTUnwrap(URL(string: "https://example.com/some/icon.png"))
        XCTAssertEqual(StorefrontService.upscaledIconURL(odd), odd)
    }

    func testPreviewAssetBecomesHeroArt() throws {
        let data = try loadFixture("fixture_topfree")
        let feed = try JSONDecoder().decode(LegacyChartFeed.self, from: data)
        let entry = try XCTUnwrap(feed.feed?.entry?.entries.first)
        let item = try XCTUnwrap(StorefrontService.item(fromChart: entry))
        XCTAssertNotNil(item.heroArtURL, "hero art must never be nil")
        let hasPreview = (entry.link ?? []).contains { $0.attributes?.imAssetType == "preview" }
        if hasPreview {
            XCTAssertNotEqual(item.heroArtURL, item.iconURL, "preview asset should win over the icon")
        } else {
            XCTAssertEqual(item.heroArtURL, item.iconURL, "no preview asset -> fall back to the icon")
        }
    }

    func testSingleEntryFormDecodes() throws {
        // limit=1 feeds can emit `entry` as a bare object; FlexibleEntries must
        // accept it instead of throwing.
        let single = """
{"feed":{"entry":{"im:name":{"label":"Solo"},"im:image":[{"label":"https://is1-ssl.mzstatic.com/x/100x100bb.png","attributes":{"height":"100"}}],"id":{"label":"https://apps.apple.com/us/app/x/id1?uo=2","attributes":{"im:id":"1","im:bundleId":"dev.solo"}},"im:price":{"label":"Get","attributes":{"amount":"0.00","currency":"USD"}},"im:artist":{"label":"Solo Labs"},"category":{"attributes":{"im:id":"6016","term":"Games","label":"Games"}},"link":[{"attributes":{"rel":"alternate","href":"https://apps.apple.com/us/app/x/id1"}},{"attributes":{"rel":"enclosure","type":"image/png","href":"https://is1-ssl.mzstatic.com/x/1024x1024bb.png","im:assetType":"preview"}}],"summary":{"label":"A single-entry feed sample."}}}}
"""
        let feed = try JSONDecoder().decode(LegacyChartFeed.self, from: Data(single.utf8))
        XCTAssertEqual(feed.feed?.entry?.entries.count, 1)
        let first = try XCTUnwrap(feed.feed?.entry?.entries.first)
        let item = try XCTUnwrap(StorefrontService.item(fromChart: first))
        XCTAssertEqual(item.name, "Solo")
        XCTAssertTrue(item.isFree)
    }

    func testPaidEntryMapsPrice() throws {
        let data = try loadFixture("fixture_toppaid")
        let feed = try JSONDecoder().decode(LegacyChartFeed.self, from: data)
        let items = (feed.feed?.entry?.entries ?? []).compactMap { StorefrontService.item(fromChart: $0) }
        for item in items {
            XCTAssertFalse(item.isFree, "top-paid entries must not be free")
            XCTAssertFalse(item.priceLabel.isEmpty, "paid entries carry a price label")
        }
    }
}
