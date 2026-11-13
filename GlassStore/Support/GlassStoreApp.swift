import SwiftUI

@main
struct GlassStoreApp: App {
    @State private var imageLoader = ImageLoader()
    @State private var regions = RegionStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(imageLoader)
                .environment(regions)
                .tint(.blue)
        }
    }
}
