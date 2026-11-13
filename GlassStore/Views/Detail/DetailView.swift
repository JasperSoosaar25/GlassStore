import SwiftUI

/// Full product page in the storefront's layout: header, screenshot rail,
/// ratings, description, what's new, information table and a glass action bar.
///
/// On appear it refreshes from the lookup endpoint so pages opened from a
/// chart (which carries no ratings or screenshots) become complete.
struct DetailView: View {
    @Environment(RegionStore.self) private var regions

    let item: StoreItem

    @State private var current: StoreItem
    @State private var lookupFailed = false
    @State private var descriptionExpanded = false

    init(item: StoreItem) {
        self.item = item
        // Start from the passed-in snapshot; the task below enriches it.
        _current = State(initialValue: item)
    }

    private var service: StorefrontFetching { StorefrontService() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if lookupFailed {
                    Label(
                        "Live details unavailable — showing chart data.",
                        systemImage: "wifi.exclamationmark"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                }
                if !current.screenshots.isEmpty {
                    ScreenshotsStrip(urls: current.screenshots)
                }
                ratingsBlock
                descriptionBlock
                whatsNewBlock
                informationBlock
                actionBar
                legal
            }
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: current.id) {
            await refresh()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            AppIconView(url: current.iconURL, side: 118, cornerRadius: 26, fallbackLetter: current.name)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(current.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(current.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                if let genre = current.genre.nonEmpty {
                    Text(genre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                GetPillButton(title: pillTitle) {
                    LinkOpener.open(current.storeURL)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var pillTitle: String {
        if current.isFree { return "GET" }
        return current.priceLabel.isEmpty ? "VIEW" : current.priceLabel
    }

    // MARK: - Ratings

    @ViewBuilder
    private var ratingsBlock: some View {
        if let rating = current.rating, rating > 0 {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(StoreFormatting.rating(rating) ?? "–")
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text("out of 5")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    StarRatingView(rating: rating)
                    if let count = current.ratingCount,
                       let text = StoreFormatting.ratingCount(count) {
                        Text("\(text) ratings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let advisory = current.contentAdvisoryRating?.nonEmpty {
                    Text(advisory)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: .capsule)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Description

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "About")
            Text(current.description)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(descriptionExpanded ? nil : 6)
                .padding(.horizontal, 20)
            Button(descriptionExpanded ? "less" : "more") {
                withAnimation(.snappy) { descriptionExpanded.toggle() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.blue)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - What's New

    @ViewBuilder
    private var whatsNewBlock: some View {
        if let notes = current.releaseNotes?.nonEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "What's New")
                if let version = current.version?.nonEmpty {
                    Text("Version \(version)")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                }
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Information

    private var informationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Information")
            VStack(spacing: 0) {
                infoRow("Developer", current.sellerName.nonEmpty ?? current.artistName)
                Divider().padding(.leading, 16)
                infoRow("Size", StoreFormatting.fileSize(from: current.fileSizeBytes) ?? "–")
                Divider().padding(.leading, 16)
                infoRow("Category", current.genre.nonEmpty ?? "–")
                Divider().padding(.leading, 16)
                infoRow("Compatibility", "iOS \(current.minimumOSVersion ?? "—")+")
                Divider().padding(.leading, 16)
                infoRow("Age Rating", current.contentAdvisoryRating ?? "–")
                Divider().padding(.leading, 16)
                infoRow("Price", current.isFree ? "Free" : (current.priceLabel.nonEmpty ?? "–"))
                Divider().padding(.leading, 16)
                infoRow("Chart Debut", current.releaseDateText ?? "–")
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Action bar

    /// The signature Liquid Glass moment of the page: a floating capsule bar
    /// grouped in a `GlassEffectContainer` so the buttons fuse into one glass
    /// shape instead of two separate islands.
    private var actionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                GetPillButton(title: pillTitle) {
                    LinkOpener.open(current.storeURL)
                }
                Button {
                    LinkOpener.open(current.storeURL)
                } label: {
                    Label("Open in App Store", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 20)
        }
    }

    private var legal: some View {
        Text("GlassStore is an independent, open-source client. Page data and artwork come from Apple's public feeds. Installing always opens the official App Store. Not affiliated with Apple.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
    }

    // MARK: - Enrichment

    private func refresh() async {
        do {
            let enriched = try await service.detail(id: item.id, storefront: regions.current.code)
            current = enriched
            lookupFailed = false
        } catch {
            // Charts/search already gave us enough to render a meaningful page.
            lookupFailed = true
        }
    }
}

private extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
