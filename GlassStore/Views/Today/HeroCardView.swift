import SwiftUI

/// Big editorial hero: full-bleed artwork, title and a glass GET pill that
/// floats over the art. Participates in the zoom transition into the detail
/// page via `matchedTransitionSource`.
struct HeroCardView: View {
    @Environment(ImageLoader.self) private var loader

    let item: StoreItem
    let badge: String
    let namespace: Namespace.ID

    @State private var artwork: UIImage?

    private var artURL: URL? { item.heroArtURL ?? item.iconURL }

    var body: some View {
        NavigationLink(value: item) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle().fill(
                            LinearGradient(colors: [.blue.opacity(0.55), .teal.opacity(0.45)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay {
                            AppIconView(url: item.iconURL, side: 96, cornerRadius: 22, fallbackLetter: item.name)
                        }
                    }
                }
                .frame(height: 420)
                .frame(maxWidth: .infinity)
                .clipped()

                LinearGradient(colors: [.black.opacity(0.62), .clear],
                               startPoint: .bottom, endPoint: .center)
                    .frame(height: 180)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                VStack(alignment: .leading, spacing: 10) {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .kerning(1.4)
                    Text(item.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(item.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            .matchedTransitionSource(id: item.id, in: namespace)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            GetPillButton(title: "GET") {
                LinkOpener.open(item.storeURL)
            }
            .padding(18)
        }
        .task(id: artURL) {
            artwork = await loader.image(for: artURL)
        }
    }
}
