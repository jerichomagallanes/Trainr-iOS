import SwiftUI
import YouTubePlayerKit

struct VideoTutorial: View {
    let video: YouTubeVideo
    let isExpanded: Bool
    let onToggle: () -> Void

    // 16:9 rather than the design's 2.02:1, which would letterbox the player.
    private static let aspectRatio: CGFloat = 16 / 9

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.card) {
            Button(action: onToggle) {
                HStack(spacing: 5) {
                    Text(isExpanded ? L10n.hideVideoTutorial : L10n.showVideoTutorial)
                        .font(.labelLarge)
                    Image(systemName: "chevron.up")
                        .font(.oneOff(14, .semibold))
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                }
                .foregroundStyle(Color.onSurface)
                .padding(.horizontal, Spacing.tight)
                .frame(height: 27)
                .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.medium))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                player
            }
        }
    }

    // Built only while the section is open: a player that outlived it would
    // keep playing in the background, which the stores treat as a subscription.
    private var player: some View {
        YouTubePlayerView(
            // Cued, not loaded: loading starts playing the moment the section
            // opens.
            YouTubePlayer(
                source: .video(id: video.id),
                parameters: .init(autoPlay: false)
            )
        )
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 5))
        .id(video.id)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.screen) {
        VideoTutorial(video: YouTubeVideo("dQw4w9WgXcQ"), isExpanded: false, onToggle: {})
        VideoTutorial(video: YouTubeVideo("dQw4w9WgXcQ"), isExpanded: true, onToggle: {})
    }
    .padding(Spacing.screen)
}
