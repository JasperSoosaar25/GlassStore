import SwiftUI

/// Five-star row with fractional fill, exactly like the storefront's rating rows.
struct StarRatingView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                star(at: index)
                    .font(.footnote)
                    .foregroundStyle(Color(.systemGray2))
            }
        }
        .accessibilityLabel("Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 5")
    }

    private func star(at index: Int) -> some View {
        let position = rating - Double(index)
        switch position {
        case 1.0...:
            return Image(systemName: "star.fill").asAny()
        case 0.25..<1.0:
            return Image(systemName: "star.leadinghalf.filled").asAny()
        default:
            return Image(systemName: "star").asAny()
        }
    }
}

extension View {
    fileprivate func asAny() -> AnyView { AnyView(self) }
}

#Preview {
    VStack(spacing: 12) {
        StarRatingView(rating: 4.5)
        StarRatingView(rating: 3.2)
        StarRatingView(rating: 0)
    }
    .padding()
}
