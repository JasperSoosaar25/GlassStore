import XCTest
@testable import GlassStore

final class FormattingTests: XCTestCase {

    func testFileSizeFormatting() {
        // 553_466_880 bytes must render as a localized "MB" string, not raw bytes.
        let text = StoreFormatting.fileSize(from: 553_466_880)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("MB") == true, "got \(text ?? "nil")")

        XCTAssertNil(StoreFormatting.fileSize(from: nil))
        XCTAssertNil(StoreFormatting.fileSize(from: 0))
    }

    func testRatingFormatting() {
        // Locale-robust: one fraction digit, either decimal separator, parses back ~4.5.
        if let text = StoreFormatting.rating(4.52691) {
            XCTAssertTrue(["4.5", "4,5"].contains(text), "got \(text)")
            XCTAssertEqual(text.replacingOccurrences(of: ",", with: ".").prefix(3), "4.5")
        } else {
            XCTFail("rating should format")
        }
        XCTAssertNil(StoreFormatting.rating(nil))
        XCTAssertNil(StoreFormatting.rating(0))
    }

    func testRatingCountCompact() {
        // Locale-robust contract: compact notation is shorter than the raw digits.
        if let text = StoreFormatting.ratingCount(29_150_135) {
            XCTAssertFalse(text.isEmpty)
            XCTAssertTrue(text.count < "29150135".count, "expected compact form, got \(text)")
        } else {
            XCTFail("ratingCount should format")
        }
        XCTAssertNil(StoreFormatting.ratingCount(nil))
    }

    func testRank() {
        XCTAssertEqual(StoreFormatting.rank(0), "1")
        XCTAssertEqual(StoreFormatting.rank(24), "25")
    }

    func testPrettyDate() {
        XCTAssertNotNil(StoreFormatting.prettyDate("2026-11-10T17:34:48Z"))
        XCTAssertNil(StoreFormatting.prettyDate("not a date"))
    }
}
