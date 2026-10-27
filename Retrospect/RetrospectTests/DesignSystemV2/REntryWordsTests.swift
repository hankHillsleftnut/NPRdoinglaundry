@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// V2 lane 0 · entry words (E2U-0 rest, G8U-0 editing) and the conversation link (E2Z-0): Paper's type
/// as additive styles, and the link's copy and 44 row.
@MainActor
@Suite(.serialized)
struct REntryWordsTests {
    @Test("your words: the inky card face at text-xl with a snug leading (E2U-0); additive")
    func wordsStyle() {
        #expect(RTextStyle.inkEntry.size == RDimension.fontSizeXl)
        #expect(abs(Double(RTextStyle.inkEntry.tracking) - RNumber.fontTrackingCard) < 0.0001)
        #expect(RTextStyle.inkEntry.leading == 1.3) // --leading-snug
        #expect(RTextStyle.inkCard.size == RDimension.fontSizeXl) // unchanged beside it
    }

    @Test("the link reads Paper's words, in SF text-md regular")
    func link() {
        #expect(RConversationLink {}.title == "show it in the conversation")
        #expect(RTextStyle.inlineLink.size == RDimension.fontSizeMd)
        #expect(RTextStyle.inlineLink.weight == .regular)
        #expect(RDimension.sizeTouchTarget == 44)
    }

    @Test("the conversation link's chevron is Paper's 14 (E31-0), not the 16 small icon")
    func chevron() {
        #expect(RConversationLink.chevronSize == 14)
        #expect(RConversationLink.chevronSize < RDimension.sizeIconSmall)
    }

    @Test("an edit fills the draft once, when it starts; a second start while editing keeps the typed words")
    func editSeedsOnce() {
        var edit = REntryEdit()
        edit.begin(from: "kept")
        #expect(edit.editing)
        #expect(edit.draft == "kept")
        edit.draft = "typed"
        edit.begin(from: "kept")
        #expect(edit.draft == "typed")
        #expect(edit.save() == "typed")
        #expect(!edit.editing)
        edit.begin(from: "saved words")
        #expect(edit.draft == "saved words")
        edit.cancel()
        #expect(!edit.editing)
    }

    /// The draft the hosted field edits, outside SwiftUI so it survives the view being rebuilt.
    @MainActor
    final class DraftBox {
        var draft = ""
        var appeared = 0
    }

    /// Hosts an editing field in a real window, as a lazy stack does when the row comes back on screen.
    private func host(_ box: DraftBox, in window: UIWindow) async throws {
        let draft = Binding(get: { box.draft }, set: { box.draft = $0 })
        let before = box.appeared
        window.rootViewController = UIHostingController(rootView:
            REntryWords(text: "kept", draft: draft, editing: true, focusOnEdit: false)
                .onAppear { box.appeared += 1 })
        window.makeKeyAndVisible()
        for _ in 0 ..< 100 where box.appeared == before {
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(150)) // lets the field's .task run
    }

    @Test("scrolling away and back while editing keeps the typed words (the field never reseeds the draft)")
    func reappearingKeepsDraft() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        let box = DraftBox()
        box.draft = "kept" // the page seeded it when editing started
        try await host(box, in: window)
        box.draft = "kept, and the words i typed"
        // gone (scrolled out of the lazy stack), then back: a new field for the same edit
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(50))
        try await host(box, in: window)
        #expect(box.appeared == 2)
        #expect(box.draft == "kept, and the words i typed")
    }
}
