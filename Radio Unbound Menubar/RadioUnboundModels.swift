import Foundation

struct StationResponse: Codable {
    let currentTrack: Track?

    enum CodingKeys: String, CodingKey {
        case currentTrack = "current-track"
    }
}

struct Track: Codable, Equatable {
    let title: String?
    let artist: String?
    let art: String?
    let start: String?   // "2026-02-18 14:34:42+00:00"
    let end: String?     // "2026-02-18 14:37:46.9+00:00"
    let status: String?  // "playing"

    // A stable identity for "same track" comparisons
    var identityKey: String {
        "\(title ?? "")|\(artist ?? "")|\(start ?? "")|\(end ?? "")"
    }
}

/// Utility: parse Live365's timestamp string reliably (includes timezone offset, may have fractional seconds)
enum Live365DateParser {
    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }

        // Normalize "YYYY-MM-DD HH:MM:SS(.fraction)+00:00" -> "YYYY-MM-DD'T'HH:MM:SS(.fraction)+00:00"
        let isoLike = s.replacingOccurrences(of: " ", with: "T")

        // Try with fractional seconds first, then without
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: isoLike) { return d }

        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: isoLike)
    }
}
