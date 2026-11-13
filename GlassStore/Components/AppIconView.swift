import SwiftUI

/// Async artwork view with a material placeholder while loading and on failure.
/// Never shows a torn or missing image — falls back to a frosted square with
/// the first letter of the app name.
struct AppIconView: View {
    @Environment(ImageLoader.self) private var loader

    let url: URL?
    let side: CGFloat
    var cornerRadius: CGFloat = .zero
    var fallbackLetter: String = "?"

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            image = await loader.image(for: url)
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Color(.systemFill))
            Text(String(fallbackLetter.prefix(1)).uppercased())
                .font(.system(size: side * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Icon sizes") {
    AppIconView(url: nil, side: 64, cornerRadius: 14, fallbackLetter: "G")
        .environment(ImageLoader())
        .padding()
}
