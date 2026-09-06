nonisolated struct YouTubeVideo: Equatable, Sendable {
    let id: String

    init(_ id: String) {
        self.id = id
    }

    // Whatever shape a URL hands back: watch links, short links, embeds,
    // Shorts, with or without trailing timestamps and tracking parameters.
    static func from(_ url: String?) -> YouTubeVideo? {
        guard let url, !url.isBlank else { return nil }

        let patterns = [
            /[?&]v=([A-Za-z0-9_-]{11})/,
            /youtu\.be\/([A-Za-z0-9_-]{11})/,
            /\/embed\/([A-Za-z0-9_-]{11})/,
            /\/shorts\/([A-Za-z0-9_-]{11})/
        ]
        for pattern in patterns {
            if let match = url.firstMatch(of: pattern) {
                return YouTubeVideo(String(match.1))
            }
        }
        return nil
    }
}
