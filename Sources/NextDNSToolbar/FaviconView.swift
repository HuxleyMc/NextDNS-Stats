import AppKit
import SwiftUI
import NextDNSToolbarCore

@MainActor
private final class FaviconStore {
    static let shared = FaviconStore()

    private let images = NSCache<NSString, NSImage>()
    private var unavailable = Set<String>()
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 8 * 1_024 * 1_024,
            diskCapacity: 64 * 1_024 * 1_024,
            diskPath: "NextDNSStatsFavicons"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 10
        session = URLSession(configuration: configuration)
    }

    func image(for domain: String) async -> NSImage? {
        let key = domain.lowercased() as NSString
        if let image = images.object(forKey: key) { return image }
        guard !unavailable.contains(domain), let url = FaviconURLProvider.url(for: domain) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = NSImage(data: data)
            else {
                unavailable.insert(domain)
                return nil
            }
            images.setObject(image, forKey: key)
            return image
        } catch {
            unavailable.insert(domain)
            return nil
        }
    }
}

struct FaviconView: View {
    let domain: String
    var size: CGFloat = 22
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                        .fill(.quaternary)
                    Text(monogram)
                        .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .task(id: domain) {
            image = await FaviconStore.shared.image(for: domain)
        }
        .accessibilityHidden(true)
    }

    private var monogram: String {
        String(domain.first.map { Character(String($0).uppercased()) } ?? "?")
    }
}
