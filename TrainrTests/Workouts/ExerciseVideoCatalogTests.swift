import Foundation
import Testing
@testable import Trainr

@Suite("Exercise video catalog")
struct ExerciseVideoCatalogTests {

    @Test("Every entry yields a URL the parser reads back to the same video")
    func urlsRoundTrip() {
        for (key, video) in ExerciseVideoCatalog.videoIDs {
            #expect(YouTubeVideo.from(ExerciseVideoCatalog.url(for: key)) == video, "\(key)")
        }
    }

    @Test("Every key is a slug the model can be asked to use")
    func keysAreSlugs() {
        for key in ExerciseVideoCatalog.videoIDs.keys {
            #expect(key.wholeMatch(of: /[a-z0-9_]+/) != nil, "\(key)")
        }
    }

    @Test("No two exercises share a video")
    func videosAreDistinct() {
        let ids = ExerciseVideoCatalog.videoIDs.values.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("An unknown key has no video")
    func unknownKey() {
        #expect(ExerciseVideoCatalog.url(for: "no_such_movement") == nil)
    }
}
