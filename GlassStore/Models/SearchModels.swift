import Foundation

/// Codable shapes for the public iTunes Search / Lookup API, e.g.
/// `https://itunes.apple.com/search?term=notes&entity=software&limit=25`
/// `https://itunes.apple.com/lookup?id=284882215`
///
/// Only the keys GlassStore displays are declared; the API returns many more
/// (we never claim more fidelity than the endpoint actually provides).
struct ITunesResponse: Codable {
    let resultCount: Int
    let results: [ITunesResult]
}

struct ITunesResult: Codable {
    let trackId: Int64?
    let trackName: String?
    let artistName: String?
    let sellerName: String?
    let bundleId: String?

    let artworkUrl60: URL?
    let artworkUrl100: URL?
    let artworkUrl512: URL?

    let formattedPrice: String?
    let price: Double?
    let currency: String?

    let averageUserRating: Double?
    let userRatingCount: Int?

    let primaryGenreName: String?
    let genres: [String]?

    let description: String?
    let releaseNotes: String?
    let version: String?
    let currentVersionReleaseDate: String?

    let minimumOsVersion: String?
    let fileSizeBytes: String?
    let contentAdvisoryRating: String?

    let screenshotUrls: [URL]?
    let ipadScreenshotUrls: [URL]?

    let trackViewUrl: URL?
    let artistViewUrl: URL?

    enum CodingKeys: String, CodingKey {
        case trackId
        case trackName
        case artistName
        case sellerName
        case bundleId
        case artworkUrl60
        case artworkUrl100
        case artworkUrl512
        case formattedPrice
        case price
        case currency
        case averageUserRating
        case userRatingCount
        case primaryGenreName
        case genres
        case description
        case releaseNotes
        case version
        case currentVersionReleaseDate
        case minimumOsVersion
        case fileSizeBytes
        case contentAdvisoryRating
        case screenshotUrls
        case ipadScreenshotUrls
        case trackViewUrl
        case artistViewUrl
    }

    /// `bundleId` is emitted as `bundleId` by search, but lookup uses the same
    /// key; declared optional either way so a missing field never throws.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trackId = try c.decodeIfPresent(Int64.self, forKey: .trackId)
        trackName = try c.decodeIfPresent(String.self, forKey: .trackName)
        artistName = try c.decodeIfPresent(String.self, forKey: .artistName)
        sellerName = try c.decodeIfPresent(String.self, forKey: .sellerName)
        bundleId = try c.decodeIfPresent(String.self, forKey: .bundleId)
        artworkUrl60 = try c.decodeIfPresent(URL.self, forKey: .artworkUrl60)
        artworkUrl100 = try c.decodeIfPresent(URL.self, forKey: .artworkUrl100)
        artworkUrl512 = try c.decodeIfPresent(URL.self, forKey: .artworkUrl512)
        formattedPrice = try c.decodeIfPresent(String.self, forKey: .formattedPrice)
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        averageUserRating = try c.decodeIfPresent(Double.self, forKey: .averageUserRating)
        userRatingCount = try c.decodeIfPresent(Int.self, forKey: .userRatingCount)
        primaryGenreName = try c.decodeIfPresent(String.self, forKey: .primaryGenreName)
        genres = try c.decodeIfPresent([String].self, forKey: .genres)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        releaseNotes = try c.decodeIfPresent(String.self, forKey: .releaseNotes)
        version = try c.decodeIfPresent(String.self, forKey: .version)
        currentVersionReleaseDate = try c.decodeIfPresent(String.self, forKey: .currentVersionReleaseDate)
        minimumOsVersion = try c.decodeIfPresent(String.self, forKey: .minimumOsVersion)
        fileSizeBytes = try c.decodeIfPresent(String.self, forKey: .fileSizeBytes)
        contentAdvisoryRating = try c.decodeIfPresent(String.self, forKey: .contentAdvisoryRating)
        screenshotUrls = try c.decodeIfPresent([URL].self, forKey: .screenshotUrls)
        ipadScreenshotUrls = try c.decodeIfPresent([URL].self, forKey: .ipadScreenshotUrls)
        trackViewUrl = try c.decodeIfPresent(URL.self, forKey: .trackViewUrl)
        artistViewUrl = try c.decodeIfPresent(URL.self, forKey: .artistViewUrl)
    }
}
