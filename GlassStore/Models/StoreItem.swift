import Foundation

/// The single model used across every screen in GlassStore.
///
/// One unified shape keeps navigation (`navigationDestination(for: StoreItem.self)`)
/// simple: any row, rail card or hero card can push a `DetailView` without
/// converting between chart / search / lookup types.
struct StoreItem: Identifiable, Hashable, Sendable {
    let id: Int64

    var name: String
    var artistName: String
    var sellerName: String
    var iconURL: URL?
    var storeURL: URL?
    var genre: String
    var priceLabel: String
    var priceAmount: Double?
    var currency: String?
    var isFree: Bool

    // Optional — charts feeds do not carry ratings, lookup does.
    var rating: Double?
    var ratingCount: Int?

    // Optional — only populated on the detail screen (lookup endpoint).
    var summary: String
    var description: String
    var releaseNotes: String?
    var version: String?
    var releaseDateText: String?
    var minimumOSVersion: String?
    var fileSizeBytes: Int64?
    var contentAdvisoryRating: String?
    var screenshots: [URL]
    var ipadScreenshots: [URL]
    var bundleIdentifier: String?

    /// Best available wide-art candidate for the Today hero:
    /// charts expose a 1024px "preview" asset; search exposes the first screenshot.
    var heroArtURL: URL?

    var displayName: String { name }
}

// MARK: - Formatting (kept as pure functions so they are trivially unit-testable)

enum StoreFormatting {

    /// 553_466_880 -> "527.6 MB" using the user's locale.
    static func fileSize(from bytes: Int64?) -> String? {
        guard let bytes, bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// 4.52691 -> "4.5" (one fraction digit, plain decimal, locale aware).
    static func rating(_ value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// 29_150_135 -> "29.2M" (compact notation, locale aware).
    static func ratingCount(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        return value.formatted(.number.notation(.compactName))
    }

    /// Chart rank badge: 1 -> "1" (styled by the caller).
    static func rank(_ index: Int) -> String {
        "\((index + 1))"
    }
}
