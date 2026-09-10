import SwiftUI
import Testing
import UIKit

@testable import Trainr

@MainActor
@Suite("Welcome screen layout")
struct WelcomeLayoutTests {

    // A 4.7" phone, the shortest size still worth supporting and the one the old layout
    // broke on. The height is what is left for content under the status bar, which is
    // what the screen is handed.
    private let shortScreen = CGSize(width: 375, height: 647)

    // What the button needs is room, not a position: a stack hands its last child
    // whatever space is left over, so the button stayed exactly where the design put it
    // and collapsed to a sliver — drawn, findable and impossible to tap. Measured
    // through the scrolling area, since a hosting view lays out no subview of its own
    // for the button.
    @Test("Keeps a full-height button out of the scrolling area on a short screen")
    func buttonKeepsItsRoom() throws {
        let carousel = try #require(
            scrollingArea(of: shortScreen), "the carousel does not scroll at all"
        )
        let left = shortScreen.height - carousel.maxY
        #expect(left >= Spacing.large + ComponentHeight.large)
    }

    // The illustration is sized from the height as well as the width, so at the default
    // text size a short screen needs no scrolling at all: the picture is what gives way.
    @Test("Fits a short screen without scrolling at the default text size")
    func carouselFitsWithoutScrolling() throws {
        let carousel = try #require(
            scrollingArea(of: shortScreen), "the carousel does not scroll at all"
        )
        #expect(carousel.content <= carousel.height)
    }

    private struct ScrollingArea {
        let maxY: CGFloat
        let height: CGFloat
        let content: CGFloat
    }

    private func scrollingArea(of size: CGSize) -> ScrollingArea? {
        let host = UIHostingController(rootView: WelcomeView {})
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        // The captions are measured on the first pass and the carousel is sized from
        // them on a later one, so the run loop is given a turn before anything is read.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        guard let scroll = verticalScroller(in: host.view) else { return nil }
        return ScrollingArea(
            maxY: host.view.convert(scroll.bounds, from: scroll).maxY,
            height: scroll.bounds.height,
            content: scroll.contentSize.height
        )
    }

    // The pager scrolls too, sideways, and its content is as wide as every page put
    // together: the vertical one is the carousel the button has to stay clear of.
    private func verticalScroller(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.contentSize.width <= scroll.bounds.width {
            return scroll
        }
        for subview in view.subviews {
            if let found = verticalScroller(in: subview) { return found }
        }
        return nil
    }
}
