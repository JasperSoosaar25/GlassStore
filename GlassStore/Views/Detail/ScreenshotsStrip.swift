import SwiftUI

/// Horizontal screenshot rail with peek-to-the-edge styling, like the
/// storefront's product pages. Images are 9:19.5 device shots; the rail keeps
/// a fixed height and lets each item size itself.
struct ScreenshotsStrip: View {
    @Environment(ImageLoader.self) private var loader

    let urls: [URL]

    @State private var images: [URL: UIImage] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(urls, id: \.absoluteString) { url in
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                        if let image = images[url] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: 200, height: 432)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 5)
                    .task {
                        if images[url] == nil {
                            images[url] = await loader.image(for: url)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
