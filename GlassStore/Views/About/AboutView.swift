import SwiftUI

/// About tab: what GlassStore is, region picker, project links, licenses and
/// the honesty block (what this app is and is not).
struct AboutView: View {
    @Environment(RegionStore.self) private var regions

    private let repoURL = URL(string: "https://github.com/glassstore-community/GlassStore")

    var body: some View {
        NavigationStack {
            List {
                Section("Storefront Region") {
                    Picker("Region", selection: Binding(
                        get: { regions.current },
                        set: { regions.switchTo($0) }
                    )) {
                        ForEach(RegionStore.catalog) { region in
                            Text("\(region.flag)  \(region.name)").tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Charts, search and details reload for the selected region.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About GlassStore") {
                    row("Version", "1.0.0 (1)")
                    row("Minimum iOS", "26.0")
                    row("Design", "Liquid Glass (iOS 26)")
                    row("License", "MIT — free to fork")
                    row("Data", "Apple public feeds · no keys · no tracking")
                }

                Section("Project") {
                    if let repoURL {
                        Link(destination: repoURL) {
                            Label("Source on GitHub", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let docs = URL(string: "https://performance-partners.apple.com/search-api") {
                        Link(destination: docs) {
                            Label("Data source documentation", systemImage: "doc.text")
                        }
                    }
                }

                Section("The honest bit") {
                    Text("GlassStore is an independent, open-source storefront client. It is not affiliated with, endorsed by, or connected to Apple. It does not install, sign or modify apps — every install button opens the official App Store. It ships with zero special entitlements, so it behaves identically whether you install it with Xcode, AltStore, SideStore, Sideloadly or any other signing tool.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
