@testable import Retrospect
import Testing

/// PX: the link comes from build configuration; with no id the button is hidden and nothing opens.
@MainActor
struct ForceUpdateModelTests {
    @Test("the store link is built from a numeric id and from nothing else")
    func link() {
        #expect(AppStoreLink.url(id: "1234567890")?.absoluteString == "itms-apps://apps.apple.com/app/id1234567890")
        #expect(AppStoreLink.url(id: " 42 ")?.absoluteString == "itms-apps://apps.apple.com/app/id42")
        #expect(AppStoreLink.url(id: nil) == nil)
        #expect(AppStoreLink.url(id: "") == nil)
        #expect(AppStoreLink.url(id: "id123") == nil)
        #expect(AppStoreLink.url(id: "12 3") == nil)
        // digits that aren't ASCII never reach the link
        #expect(AppStoreLink.url(id: "\u{0661}\u{0662}\u{0663}") == nil)
        #expect(AppStoreLink.url(id: "12\u{00BD}") == nil)
        #expect(AppStoreLink.url(id: "\u{FF11}\u{FF12}") == nil)
    }

    @Test("update opens the store page once per press")
    func opens() {
        var opened: [String] = []
        let model = ForceUpdateModel(storeURL: AppStoreLink.url(id: "99")) { opened.append($0.absoluteString) }
        #expect(model.canUpdate)
        model.update()
        #expect(opened == ["itms-apps://apps.apple.com/app/id99"])
        model.update()
        #expect(opened.count == 2)
    }

    @Test("with no store id the button is hidden and pressing does nothing")
    func noID() {
        var opened = 0
        let model = ForceUpdateModel(storeURL: AppStoreLink.url(id: nil)) { _ in opened += 1 }
        #expect(!model.canUpdate)
        model.update()
        #expect(opened == 0)
    }

    @Test("the words say nothing saved is lost, and never the server's text")
    func words() {
        #expect(ForceUpdateModel.line.contains("nothing you've saved is lost"))
        #expect(ForceUpdateModel.title == "there's a newer retrospect.")
    }

    @Test("the launcher lists the three states")
    func launcher() {
        #expect(ScreenRegistry.screen("PX")?.states == ["rest", "offline", "noStoreLink", "cover"])
    }
}
