import Foundation

/// Codable shapes for Apple's legacy public chart feeds, e.g.
/// `https://itunes.apple.com/us/rss/topfreeapplications/limit/25/json`
///
/// The feed is Atom-flavoured JSON: most values are wrapped in `{ "label": ... }`
/// envelopes. These models mirror that shape exactly; mapping into `StoreItem`
/// happens in `StorefrontService`.
///
/// Known quirk: with `limit=1` some storefronts return a single entry *object*
/// instead of an array. `FlexibleEntries` decodes both forms so a rank-1-only
/// request can never crash the parser.
struct LegacyChartFeed: Codable {
    struct Feed: Codable {
        struct Entry: Codable {
            struct Labelled: Codable {
                let label: String
            }
            struct Price: Codable {
                struct Attributes: Codable {
                    let amount: String?
                    let currency: String?
                }
                let label: String?
                let attributes: Attributes?
            }
            struct ImageItem: Codable {
                struct Attributes: Codable {
                    let height: String?
                }
                let label: String
                let attributes: Attributes?
            }
            struct Category: Codable {
                struct Attributes: Codable {
                    let imId: String?
                    let term: String?
                    let label: String?

                    enum CodingKeys: String, CodingKey {
                        case imId = "im:id"
                        case term
                        case label
                    }
                let attributes: Attributes?
            }
            struct Identifier: Codable {
                struct Attributes: Codable {
                    let imId: String?
                    let imBundleId: String?

                    enum CodingKeys: String, CodingKey {
                        case imId = "im:id"
                        case imBundleId = "im:bundleId"
                    }
                let label: String?
                let attributes: Attributes?
            }
            struct ReleaseDate: Codable {
                struct Attributes: Codable {
                    let label: String?
                }
                let label: String?
                let attributes: Attributes?
            }
            struct Link: Codable {
                struct Attributes: Codable {
                    let rel: String?
                    let type: String?
                    let href: String?
                    let imAssetType: String?

                    enum CodingKeys: String, CodingKey {
                        case rel
                        case type
                        case href
                        case imAssetType = "im:assetType"
                    }
                let attributes: Attributes?
            }
            struct ContentType: Codable {
                let attributes: Labelled?
            }

            let imName: Labelled?
            let imArtist: Labelled?
            let imPrice: Price?
            let imImage: [ImageItem]?
            let imReleaseDate: ReleaseDate?
            let category: Category?
            let id: Identifier?
            let link: [Link]?
            let summary: Labelled?
            let rights: Labelled?
            let title: Labelled?
            let imContentType: ContentType?

            enum CodingKeys: String, CodingKey {
                case imName = "im:name"
                case imArtist = "im:artist"
                case imPrice = "im:price"
                case imImage = "im:image"
                case imReleaseDate = "im:releaseDate"
                case category
                case id
                case link
                case summary
                case rights
                case title
                case imContentType = "im:contentType"
            }
        }

        /// Decodes `entry` as either an array or a single object.
        struct FlexibleEntries: Codable {
            let entries: [Entry]

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let array = try? container.decode([Entry].self) {
                    entries = array
                } else if let single = try? container.decode(Entry.self) {
                    entries = [single]
                } else {
                    entries = []
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(entries)
            }
        }

        let entry: FlexibleEntries?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            entry = try container.decodeIfPresent(FlexibleEntries.self, forKey: .entry)
        }

        enum CodingKeys: String, CodingKey { case entry }
    }

    let feed: Feed?
}
