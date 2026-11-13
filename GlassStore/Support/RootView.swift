import SwiftUI

/// Root tab bar. On iOS 26 the system tab bar already renders as Liquid Glass;
/// `.tabBarMinimizeBehavior(.onScrollDown)` adds the signature collapse-on-scroll
/// from the native storefront apps.
struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }

            ChartsView()
                .tabItem { Label("Charts", systemImage: "chart.bar.xaxis") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#if DEBUG
#Preview("Tabs") {
    RootView()
        .environment(ImageLoader())
        .environment(RegionStore.shared)
}
#endif
