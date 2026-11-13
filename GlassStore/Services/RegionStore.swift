import Foundation
import Observation

/// Storefront (region) selection, persisted in UserDefaults.
/// The public endpoints GlassStore reads are per-storefront, so this single
/// setting drives charts, search and detail lookups alike.
@Observable
final class RegionStore {
    static let shared = RegionStore()

    struct Region: Identifiable, Hashable {
        let code: String
        let flag: String
        let name: String
        var id: String { code }
    }

    /// A practical subset — the endpoint supports many more storefronts;
    /// extend freely, the list only feeds a picker.
    static let catalog: [Region] = [
        Region(code: "us", flag: "🇺🇸", name: "United States"),
        Region(code: "gb", flag: "🇬🇧", name: "United Kingdom"),
        Region(code: "ca", flag: "🇨🇦", name: "Canada"),
        Region(code: "au", flag: "🇦🇺", name: "Australia"),
        Region(code: "de", flag: "🇩🇪", name: "Germany"),
        Region(code: "fr", flag: "🇫🇷", name: "France"),
        Region(code: "es", flag: "🇪🇸", name: "Spain"),
        Region(code: "it", flag: "🇮🇹", name: "Italy"),
        Region(code: "nl", flag: "🇳🇱", name: "Netherlands"),
        Region(code: "se", flag: "🇸🇪", name: "Sweden"),
        Region(code: "pl", flag: "🇵🇱", name: "Poland"),
        Region(code: "jp", flag: "🇯🇵", name: "Japan"),
        Region(code: "cn", flag: "🇨🇳", name: "China"),
        Region(code: "in", flag: "🇮🇳", name: "India"),
        Region(code: "br", flag: "🇧🇷", name: "Brazil"),
        Region(code: "mx", flag: "🇲🇽", name: "Mexico"),
        Region(code: "tr", flag: "🇹🇷", name: "Türkiye"),
        Region(code: "ae", flag: "🇦🇪", name: "United Arab Emirates"),
        Region(code: "kr", flag: "🇰🇷", name: "South Korea"),
        Region(code: "ee", flag: "🇪🇪", name: "Estonia"),
    ]

    private static let key = "glassstore.storefront"

    var current: Region {
        didSet {
            UserDefaults.standard.set(current.code, forKey: Self.key)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = Self.catalog.first { $0.code == saved } ?? Self.catalog[0]
    }

    /// Notifies dependent views that their data is now stale. Today/Charts
    /// listen for this id and reload.
    var reloadToken: UUID = UUID()

    func switchTo(_ region: Region) {
        guard region != current else { return }
        current = region
        reloadToken = UUID()
    }
}
