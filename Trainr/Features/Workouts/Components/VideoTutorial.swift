import SwiftUI
import YouTubePlayerKit

struct VideoTutorial: View {
    let video: YouTubeVideo
    let isExpanded: Bool
    let onToggle: () -> Void

    // YouTube serves 16:9; the design's 352x174 rectangle is 2.02:1, and
    // matching it would letterbox the player. Held from the moment the section
    // opens so the list does not jump as the player finds its own size.
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
                .foregroundStyle(Color.slate800)
                .padding(.horizontal, Spacing.tight)
                .frame(height: 27)
                .background(Color.gray100, in: .rect(cornerRadius: CornerRadius.medium))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                player
            }
        }
    }

    // A player is built only while the section is open, and goes with it. One
    // that outlived the screen would keep playing with the app in the
    // background, which the stores treat as substituting for a subscription.
    private var player: some View {
        YouTubePlayerView(
            // Cued rather than loaded: cueing shows YouTube's own poster frame
            // and its own play button, and waits to be asked. Loading would
            // start playing the moment the section opened.
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
