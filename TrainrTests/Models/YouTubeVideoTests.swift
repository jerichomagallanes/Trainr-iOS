import Testing
@testable import Trainr

struct YouTubeVideoTests {

    @Test func everyLinkShapeYieldsTheSameID() {
        for url in [
            "https://www.youtube.com/watch?v=6mf0oa2GGUc",
            "https://www.youtube.com/watch?v=6mf0oa2GGUc&t=42s",
            "https://youtu.be/6mf0oa2GGUc",
            "https://www.youtube.com/embed/6mf0oa2GGUc",
            "https://www.youtube.com/shorts/6mf0oa2GGUc"
        ] {
            #expect(YouTubeVideo.from(url) == YouTubeVideo("6mf0oa2GGUc"), "\(url)")
        }
    }

    @Test func junkYieldsNothing() {
        #expect(YouTubeVideo.from(nil) == nil)
        #expect(YouTubeVideo.from("") == nil)
        #expect(YouTubeVideo.from("https://example.com/watch?v=short") == nil)
    }

    @Test func everyCatalogEntryBuildsAWatchURL() {
        for key in ExerciseVideoCatalog.videoIDs.keys {
            let url = ExerciseVideoCatalog.url(for: key)
            #expect(url?.hasPrefix("https://www.youtube.com/watch?v=") == true)
        }
        #expect(ExerciseVideoCatalog.url(for: "not_a_movement") == nil)
    }
}
