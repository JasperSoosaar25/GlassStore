import SwiftUI

/// The App Store's signature GET pill, rebuilt with Liquid Glass:
/// an interactive, blue-tinted capsule that refracts the content behind it.
struct GetPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
        }
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .clipShape(.capsule)
    }
}

#Preview {
    GetPillButton(title: "GET") {}
        .padding()
        .background(LinearGradient(colors: [.teal, .indigo], startPoint: .top, endPoint: .bottom))
}
