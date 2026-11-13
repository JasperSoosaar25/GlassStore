import Foundation

/// The four public chart feeds GlassStore uses (legacy iTunes RSS, verified live).
enum ChartKind: String, CaseIterable, Identifiable, Sendable {
    case topFree = "topfreeapplications"
    case topPaid = "toppaidapplications"
    case topGrossing = "topgrossingapplications"
    case newApps = "newapplications"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topFree: return "Top Free"
        case .topPaid: return "Top Paid"
        case .topGrossing: return "Top Grossing"
        case .newApps: return "New"
        }
    }
}

enum StorefrontError: Error, LocalizedError, Sendable {
    case badURL
    case network(String)
    case http(status: Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "The request could not be built. Check the search term or region."
        case .network(let message):
            return "Network request failed. \(message)"
        case .http(let status):
            return "The service answered with HTTP \(status). Try again in a moment."
        case .decoding(let message):
            return "The service returned data in an unexpected shape. \(message)"
        }
    }
}

protocol StorefrontFetching: Sendable {
    func chart(_ kind: ChartKind, storefront: String, limit: Int) async throws -> [StoreItem]
    func search(term: String, storefront: String, limit: Int) async throws -> [StoreItem]
    func detail(id: Int64, storefront: String) async throws -> StoreItem
}

/// Live implementation over Apple's public, key-less endpoints.
///
/// - Charts: `https://itunes.apple.com/{storefront}/rss/{chart}/limit/{n}/json`
/// - Search: `https://itunes.apple.com/search?term=...&entity=software`
/// - Detail: `https://itunes.apple.com/lookup?id={trackId}`
///
/// All requests are HTTPS, no authentication, no tracking. GlassStore adds
/// nothing of its own to these payloads.
final class StorefrontService: StorefrontFetching {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    func chart(_ kind: ChartKind, storefront: String, limit: Int) async throws -> [StoreItem] {
        let url = try Self.chartURL(kind: kind, storefront: storefront, limit: limit)
        let (data, response) = try await perform(url)
        let feed = try decode(LegacyChartFeed.self, from: data, response: response)
        let entries = feed.feed?.entry?.entries ?? []
        return entries.compactMap { Self.item(fromChart: $0) }
    }

    func search(term: String, storefront: String, limit: Int) async throws -> [StoreItem] {
        let url = try Self.searchURL(term: term, storefront: storefront, limit: limit)
        let (data, response) = try await perform(url)
        let payload = try decode(ITunesResponse.self, from: data, response: response)
        return payload.results.compactMap { Self.item(fromSearch: $0) }
    }

    func detail(id: Int64, storefront: String) async throws -> StoreItem {
        let url = try Self.lookupURL(id: id, storefront: storefront)
        let (data, response) = try await perform(url)
        let payload = try decode(ITunesResponse.self, from: data, response: response)
        guard let best = payload.results.first(where: { $0.trackId == id }) ?? payload.results.first else {
            throw StorefrontError.decoding("No result for id \(id).")
        }
        guard var item = Self.item(fromSearch: best) else {
            throw StorefrontError.decoding("Result \(id) is not an app (media type mismatch?).")
        }
        // Search results carry a short description; the full one comes from lookup.
        item.description = best.description ?? item.description
        return item
    }

    // MARK: - URL building (pure, unit-tested)

    static func chartURL(kind: ChartKind, storefront: String, limit: Int) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/\(storefront)/rss/\(kind.rawValue)/limit/\(limit)/json"
        guard let url = components.url else { throw StorefrontError.badURL }
        return url
    }

    static func searchURL(term: String, storefront: String, limit: Int) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: storefront),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { throw StorefrontError.badURL }
        return url
    }

    static func lookupURL(id: Int64, storefront: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        components.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "country", value: storefront),
        ]
        guard let url = components.url else { throw StorefrontError.badURL }
        return url
    }

    /// Store page used by every GET / Open button — always the official page.
    static func storePageURL(id: Int64, storefront: String) -> URL? {
        URL(string: "https://apps.apple.com/\(storefront)/app/id\(id)")
    }

    // MARK: - Mapping

    static func item(fromChart entry: LegacyChartFeed.Feed.Entry) -> StoreItem? {
        guard let idText = entry.id?.attributes?.imId, let id = Int64(idText) else { return nil }

        let price = entry.imPrice?.attributes
        let amount = price?.amount.flatMap { Double($0) }
        let free = (amount ?? 0) == 0

        let icon = bestIcon(from: entry.imImage ?? [])
        let storeLink = (entry.link ?? []).first(where: { $0.attributes?.rel == "alternate" })
            .flatMap { $0.attributes?.href } ?? entry.id?.label
        let previewAsset = (entry.link ?? []).first(where: { $0.attributes?.imAssetType == "preview" })
            .flatMap { $0.attributes?.href }

        return StoreItem(
            id: id,
            name: entry.imName?.label ?? entry.title?.label ?? "Unknown",
            artistName: entry.imArtist?.label ?? entry.rights?.label ?? "",
            sellerName: entry.imArtist?.label ?? "",
            iconURL: icon,
            storeURL: storeLink.flatMap { URL(string: $0) },
            genre: entry.category?.attributes?.label ?? entry.category?.attributes?.term ?? "",
            priceLabel: free ? "Free" : (entry.imPrice?.label ?? price?.currency ?? ""),
            priceAmount: amount,
            currency: price?.currency,
            isFree: free,
            rating: nil,
            ratingCount: nil,
            summary: entry.summary?.label ?? "",
            description: entry.summary?.label ?? "",
            releaseNotes: nil,
            version: nil,
            releaseDateText: entry.imReleaseDate?.attributes?.label,
            minimumOSVersion: nil,
            fileSizeBytes: nil,
            contentAdvisoryRating: nil,
            screenshots: [],
            ipadScreenshots: [],
            bundleIdentifier: entry.id?.attributes?.imBundleId,
            heroArtURL: previewAsset.flatMap { URL(string: $0) } ?? icon
        )
    }

    static func item(fromSearch result: ITunesResult) -> StoreItem? {
        guard let id = result.trackId, let name = result.trackName else { return nil }

        let price = result.price ?? 0
        let free = price == 0

        return StoreItem(
            id: id,
            name: name,
            artistName: result.artistName ?? result.sellerName ?? "",
            sellerName: result.sellerName ?? result.artistName ?? "",
            iconURL: result.artworkUrl512 ?? result.artworkUrl100 ?? result.artworkUrl60,
            storeURL: result.trackViewUrl,
            genre: result.primaryGenreName ?? result.genres?.first ?? "",
            priceLabel: result.formattedPrice ?? (free ? "Free" : ""),
            priceAmount: result.price,
            currency: result.currency,
            isFree: free,
            rating: result.averageUserRating,
            ratingCount: result.userRatingCount,
            summary: result.description ?? "",
            description: result.description ?? "",
            releaseNotes: result.releaseNotes,
            version: result.version,
            releaseDateText: result.currentVersionReleaseDate.flatMap(Self.prettyDate),
            minimumOSVersion: result.minimumOsVersion,
            fileSizeBytes: result.fileSizeBytes.flatMap { Int64($0) },
            contentAdvisoryRating: result.contentAdvisoryRating,
            screenshots: result.screenshotUrls ?? [],
            ipadScreenshots: result.ipadScreenshotUrls ?? [],
            bundleIdentifier: result.bundleId,
            heroArtURL: (result.screenshotUrls ?? []).first ?? result.artworkUrl512 ?? result.artworkUrl100
        )
    }

    /// `.../53x53bb.png` -> `.../512x512bb.png` — the image CDN accepts arbitrary
    /// square sizes; charts only ship 53/75/100px icons.
    static func upscaledIconURL(_ url: URL) -> URL {
        guard let match = url.path.range(of: #"/\d+x\d+bb\.(png|jpg|jpeg|webp)$"#, options: .regularExpression) else {
            return url
        }
        let matched = url.path[match]
        let ext = matched.contains("jpg") ? "jpg" : (matched.contains("png") ? "png" : "webp")
        let newPath = url.path.replacingCharacters(in: match, with: "/512x512bb.\(ext)")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = newPath
        return components?.url ?? url
    }

    static func bestIcon(from images: [LegacyChartFeed.Feed.Entry.ImageItem]) -> URL? {
        // Prefer the largest declared height; all sizes share one base artwork.
        let sorted = images.sorted { (Int($0.attributes?.height ?? "0") ?? 0) > (Int($1.attributes?.height ?? "0") ?? 0) }
        guard let raw = sorted.first?.label, let url = URL(string: raw) else { return nil }
        return upscaledIconURL(url)
    }

    static func prettyDate(_ iso: String) -> String? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Transport

    private func perform(_ url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch {
            throw StorefrontError.network(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, response: URLResponse) throws -> T {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw StorefrontError.http(status: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw StorefrontError.decoding(error.localizedDescription)
        }
    }
}
