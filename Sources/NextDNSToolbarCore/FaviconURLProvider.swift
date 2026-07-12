import Foundation

public enum FaviconURLProvider {
    private static let baseURL = URL(string: "https://icons.duckduckgo.com/ip3/")!

    public static func url(for domain: String) -> URL? {
        var normalized = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasSuffix(".") { normalized.removeLast() }
        guard !normalized.isEmpty,
              normalized.contains("."),
              !normalized.contains("://"),
              !normalized.contains("/"),
              normalized.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return nil }

        return baseURL.appendingPathComponent(normalized).appendingPathExtension("ico")
    }
}
