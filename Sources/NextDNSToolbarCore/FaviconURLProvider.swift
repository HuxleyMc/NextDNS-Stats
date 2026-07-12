import Foundation

public enum FaviconURLProvider {
    private static let baseURL = URL(string: "https://icons.duckduckgo.com/ip3/")!

    public static func url(for domain: String) -> URL? {
        guard let normalized = normalizedDomain(domain) else { return nil }
        return baseURL.appendingPathComponent(normalized).appendingPathExtension("ico")
    }

    public static func candidateDomains(for domain: String) -> [String] {
        guard let normalized = normalizedDomain(domain) else { return [] }
        var labels = normalized.split(separator: ".").map(String.init)
        var candidates = [normalized]
        while labels.count > 2 {
            labels.removeFirst()
            candidates.append(labels.joined(separator: "."))
        }
        return candidates
    }

    private static func normalizedDomain(_ domain: String) -> String? {
        var normalized = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasSuffix(".") { normalized.removeLast() }
        guard !normalized.isEmpty,
              normalized.contains("."),
              !normalized.contains("://"),
              !normalized.contains("/"),
              normalized.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return nil }
        return normalized
    }
}
