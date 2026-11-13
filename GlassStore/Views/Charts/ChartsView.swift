import SwiftUI

/// The Charts tab: segmented public charts with the storefront's numbered-row
/// presentation, plus region-aware reloading.
struct ChartsView: View {
    @Environment(RegionStore.self) private var regions

    @State private var selection: ChartKind = .topFree
    @State private var items: [StoreItem] = []
    @State private var phase: Phase = .loading
    @State private var loadAttempt = 0

    private enum Phase {
        case loading
        case ready
        case failed(String)
    }

    private var service: StorefrontFetching { StorefrontService() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Chart", selection: $selection) {
                    ForEach(ChartKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                switch phase {
                case .loading:
                    LoadingStateView()
                    Spacer()
                case .failed(let message):
                    FailureStateView(message: message) { loadAttempt += 1 }
                    Spacer()
                case .ready:
                    if items.isEmpty {
                        EmptyStateView(
                            title: "No entries",
                            message: "This chart is empty for \(regions.current.name) right now."
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                                ChartRow(index: pair.offset, item: pair.element)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Charts")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: StoreItem.self) { item in
                DetailView(item: item)
            }
        }
        .task(id: "\(selection)-\(regions.reloadToken)-\(loadAttempt)") {
            await load()
        }
    }

    private func load() async {
        phase = .loading
        do {
            items = try await service.chart(selection, storefront: regions.current.code, limit: 25)
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// One numbered chart row: rank, icon, name/category, rating, GET pill.
struct ChartRow: View {
    let index: Int
    let item: StoreItem

    var body: some View {
        NavigationLink(value: item) {
            HStack(spacing: 14) {
                Text(StoreFormatting.rank(index))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30)

                AppIconView(url: item.iconURL, side: 56, cornerRadius: 13, fallbackLetter: item.name)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.genre)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let count = item.ratingCount, let text = StoreFormatting.ratingCount(count) {
                            Text("· \(text) ratings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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
        .buttonStyle(.plain)
    }

    private var pillTitle: String {
        if item.isFree { return "GET" }
        return item.priceLabel.isEmpty ? "VIEW" : item.priceLabel
    }
}
