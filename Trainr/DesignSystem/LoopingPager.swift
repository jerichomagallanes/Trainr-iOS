import SwiftUI

// A swipe carousel that wraps: the page after the last is the first again.
// Built as the classic sentinel trick — a copy of the last page before the
// first and of the first after the last, with an unanimated jump when a
// sentinel settles.
struct LoopingPager<Item: Hashable, Content: View>: View {
    let items: [Item]
    @Binding var currentIndex: Int
    @ViewBuilder let content: (Item) -> Content

    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            if let last = items.last, let first = items.first {
                content(last).tag(0)
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    content(item).tag(index + 1)
                }
                content(first).tag(items.count + 1)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selection) {
            if selection == 0 {
                currentIndex = items.count - 1
                Task { selection = items.count }
            } else if selection == items.count + 1 {
                currentIndex = 0
                Task { selection = 1 }
            } else {
                currentIndex = selection - 1
            }
        }
    }
}
