import SwiftUI

/// The Today tab: one editorial hero, trending rails and a mini chart —
/// the same content skeleton as the storefront's Today page, rebuilt with
/// Liquid Glass accents.
struct TodayView: View {
    @Environment(RegionStore.self) private var regions
    @Environment(ImageLoader.self) private var loader

    @State private var topFree: [StoreItem] = []
    @State private var newApps: [StoreItem] = []
    @State private var grossing: [StoreItem] = []
    @State private var phase: Phase = .loading
    @State private var loadAttempt = 0

    @Namespace private var zoom

    private enum Phase {
        case loading
        case ready
        case failed(String)
    }

    private var service: StorefrontFetching { StorefrontService() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header

                    switch phase {
                    case .loading:
                        LoadingStateView()
                    case .failed(let message):
                        FailureStateView(message: message) { loadAttempt += 1 }
                    case .ready:
                        readyContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .refreshable { await load() }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: StoreItem.self) { item in
                DetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: zoom))
            }
        }
        .task(id: "\(regions.reloadToken)-\(loadAttempt)") {
            await load()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("GlassStore")
                .font(.largeTitle.weight(.bold))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var readyContent: some View {
        if let hero = topFree.first {
            HeroCardView(item: hero, badge: "TOP FREE #1", namespace: zoom)
        }
        if topFree.count > 1 {
            editorial(
                title: "Now Trending",
                subtitle: "Everyone's downloading these",
                items: Array(topFree.dropFirst().prefix(12))
            )
        }
        if !newApps.isEmpty {
            editorial(
                title: "Fresh on the Store",
                subtitle: "New releases, updated live",
                items: Array(newApps.prefix(12))
            )
        }
        if !grossing.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Top Grossing", subtitle: "Where the money is")
                VStack(spacing: 0) {
                    ForEach(Array(grossing.prefix(5).enumerated()), id: \.element.id) { pair in
                        RankRow(index: pair.offset, item: pair.element)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        Text("Charts and artwork come from Apple's public storefront feeds. GlassStore is not affiliated with Apple. Installing always opens the official App Store.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editorial(title: String, subtitle: String, items: [StoreItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            RailCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    private static var dateLine: String {
        let now = Date.now
        return now.formatted(.weekday(.wide)) + " · " + now.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Data

    private func load() async {
        if phase != .loading { phase = .loading }
        do {
            async let free = service.chart(.topFree, storefront: regions.current.code, limit: 25)
            async let fresh = service.chart(.newApps, storefront: regions.current.code, limit: 25)
            async let money = service.chart(.topGrossing, storefront: regions.current.code, limit: 25)
            topFree = try await free
            newApps = try await fresh
            grossing = try await money
            if topFree.isEmpty {
                phase = .failed("The charts feed came back empty for \(regions.current.name).")
            } else {
                phase = .ready
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// Horizontal rail card used by the editorial sections.
private struct RailCard: View {
    let item: StoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppIconView(url: item.iconURL, side: 128, cornerRadius: 28, fallbackLetter: item.name)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
            Text(item.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 132)
    }
}

/// Numbered row for compact in-page charts. The row navigates to the detail
/// page; the GET pill opens the official store page (nested button wins the tap).
private struct RankRow: View {
    let index: Int
    let item: StoreItem

    var body: some View {
        NavigationLink(value: item) {
            HStack(spacing: 14) {
                Text(StoreFormatting.rank(index))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                AppIconView(url: item.iconURL, side: 52, cornerRadius: 12, fallbackLetter: item.name)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(item.genre).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                GetPillButton(title: pillTitle) {
                    LinkOpener.open(item.storeURL)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var pillTitle: String {
        if item.isFree { return "GET" }
        return item.priceLabel.isEmpty ? "VIEW" : item.priceLabel
    }
}

/// Opens external storefront pages. One choke point for review and testing.
enum LinkOpener {
    @MainActor
    static func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}
