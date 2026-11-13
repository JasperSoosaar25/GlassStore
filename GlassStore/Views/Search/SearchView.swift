import SwiftUI

/// The Search tab. Uses the system Liquid Glass search field (`.searchable`
/// renders as glass on iOS 26) with the minimized toolbar behavior, a
/// debounced query, and storefront-styled result rows.
struct SearchView: View {
    @Environment(RegionStore.self) private var regions

    @State private var query = ""
    @State private var results: [StoreItem] = []
    @State private var phase: Phase = .idle
    @State private var searchTaskId = UUID()

    private enum Phase: Equatable {
        case idle
        case searching
        case ready
        case failed(String)
    }

    private let debounce: Duration = .milliseconds(400)
    private var service: StorefrontFetching { StorefrontService() }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .idle:
                    EmptyStateView(
                        title: "Search the Store",
                        message: "Find any app on the storefront. Results come from Apple's public search feed."
                    )
                case .searching:
                    LoadingStateView()
                case .failed(let message):
                    FailureStateView(message: message) {
                        if !query.isEmpty { searchTaskId = UUID() }
                    }
                case .ready:
                    if results.isEmpty {
                        EmptyStateView(
                            title: "No results",
                            message: "Nothing matched “\(query)”. Try a different spelling or fewer words."
                        )
                    } else {
                        List(results) { item in
                            NavigationLink(value: item) {
                                SearchRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: StoreItem.self) { item in
                DetailView(item: item)
            }
            .searchable(text: $query, prompt: "Games, tools, developers…")
            .searchToolbarBehavior(.minimized)
        }
        .task(id: "\(query)-\(searchTaskId)-\(regions.reloadToken)") {
            await runSearch()
        }
    }

    private func runSearch() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            if case .ready = phase { } else { phase = .idle }
            results = []
            return
        }
        do {
            try await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            phase = .searching
            results = try await service.search(
                term: term,
                storefront: regions.current.code,
                limit: 25
            )
            phase = .ready
        } catch is CancellationError {
            // A newer query superseded this one — nothing to do.
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// Storefront-style result row.
struct SearchRow: View {
    let item: StoreItem

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(url: item.iconURL, side: 56, cornerRadius: 13, fallbackLetter: item.name)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let rating = item.rating, rating > 0 {
                    HStack(spacing: 6) {
                        StarRatingView(rating: rating)
                        if let count = item.ratingCount,
                           let text = StoreFormatting.ratingCount(count) {
                            Text(text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            GetPillButton(title: pillTitle) {
                LinkOpener.open(item.storeURL)
            }
        }
        .padding(.vertical, 6)
    }

    private var pillTitle: String {
        if item.isFree { return "GET" }
        return item.priceLabel.isEmpty ? "VIEW" : item.priceLabel
    }
}
