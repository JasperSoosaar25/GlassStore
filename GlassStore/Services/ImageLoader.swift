import UIKit

/// Two-tier image cache (memory + disk) used by every artwork and screenshot.
///
/// `NSCache` handles memory pressure on its own; the disk tier lives under
/// Caches/glassstore-images so the OS can purge it without touching user data.
/// Only URLs already fetched are stored — nothing is prefetched, nothing is
/// uploaded anywhere.
actor DiskImageCache {
    private let folder: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first
            .map { $0.appendingPathComponent("glassstore-images", isDirectory: true) }
        self.folder = base ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private func fileURL(for url: URL) -> URL {
        // Stable, filesystem-safe key: first 40 hex chars of the URL bytes.
        let hex = url.absoluteString.data(using: .utf8)?
            .map { String(format: "%02x", $0) }
            .joined() ?? ""
        let key = String(hex.prefix(40))
        return folder.appendingPathComponent(key.isEmpty ? "item" : key)
    }

    func data(for url: URL) -> Data? {
        let target = fileURL(for: url)
        return try? Data(contentsOf: target)
    }

    func store(_ data: Data, for url: URL) {
        let target = fileURL(for: url)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
        } catch {
            // Disk full or folder unwritable — caching is best effort, never fatal.
        }
    }
}

/// Observable facade the views talk to. One instance is injected into the
/// environment at the app root.
@Observable
final class ImageLoader {
    private let memory = NSCache<NSURL, UIImage>()
    private let disk: DiskImageCache

    init(disk: DiskImageCache = DiskImageCache()) {
        self.disk = disk
        memory.countLimit = 300
    }

    /// Returns the cached image, or fetches it. Main-actor safe to call from
    /// SwiftUI `task` blocks; returns nil on failure (views fall back to a
    /// placeholder material — never a broken image view).
    func image(for url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let hit = memory.object(forKey: url as NSURL) { return hit }
        if let cached = await disk.data(for: url), let image = UIImage(data: cached) {
            memory.setObject(image, forKey: url as NSURL)
            return image
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: url as NSURL)
            await disk.store(data, for: url)
            return image
        } catch {
            return nil
        }
    }
}
