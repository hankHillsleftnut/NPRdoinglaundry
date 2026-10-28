import Foundation
@testable import Retrospect
import SwiftUI
import Testing

/// A connect the test lands by hand: `connect` waits until `land(_:)`. Wraps the sample, so the
/// rows and the meter are the sample's.
@MainActor
@Observable
private final class HeldConnect: Flows.Connect {
    private let sample = SampleConnect()
    private var continuation: CheckedContinuation<Flows.ConnectOutcome, Never>?
    private var pendingID: String?
    private(set) var calls = 0

    var sources: [Flows.ConnectSource] {
        sample.sources
    }

    var knowsYou: Flows.KnowsYou {
        sample.knowsYou
    }

    var isWaiting: Bool {
        continuation != nil
    }

    func connect(_ id: Flows.ConnectSource.ID) async -> Flows.ConnectOutcome {
        calls += 1
        pendingID = id
        return await withCheckedContinuation { continuation = $0 }
    }

    /// Lands the waiting connect: connected (the sample connects the row), or not.
    func land(_ outcome: Flows.ConnectOutcome) async {
        if outcome == .connected, let pendingID {
            _ = await sample.connect(pendingID)
        }
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

/// Fixed sources in any contract state, for the states the sample never reaches.
@MainActor
@Observable
private final class StubConnect: Flows.Connect {
    var sources: [Flows.ConnectSource]
    var knowsYou: Flows.KnowsYou
    private(set) var asked: [String] = []

    init(_ sources: [Flows.ConnectSource], level: Flows.KnowsYou.Level = .little) {
        self.sources = sources
        knowsYou = Flows.KnowsYou(filled: 0, steps: 6, level: level)
    }

    static func source(_ id: String, _ state: Flows.ConnectSource.State, group: Flows.SourceGroup = .onThisIphone) -> Flows.ConnectSource {
        Flows.ConnectSource(id: id, name: id, purpose: "", symbol: "circle", group: group, kind: .onDevice, state: state)
    }

    func connect(_ id: Flows.ConnectSource.ID) async -> Flows.ConnectOutcome {
        asked.append(id)
        return .notConnected
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ConnectModelTests {
    @MainActor
    private final class Exits {
        var done: [ConnectModel.Exit] = []
        var backs = 0
    }

    private let exits = Exits()

    private func make(_ data: (any Flows.Connect)? = nil) -> ConnectModel {
        let exits = exits
        return ConnectModel(
            data: data ?? SampleConnect(),
            onDone: { exits.done.append($0) },
            onBack: { exits.backs += 1 }
        )
    }

    /// Lets a connect started with `Task` reach its `await`.
    private func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    // MARK: What the page shows

    @Test("Paper 2190-0's rows in the founder's list: calendar connected, health and google to connect")
    func rowsArePapers() {
        let model = make()
        #expect(model.onThisIphone.map(\.name) == ["calendar", "health"])
        #expect(model.yourOtherApps.map(\.name) == ["google"])
        #expect(model.onThisIphone.map(\.purpose) == ["your days, and who's in them", "sleep, steps and workouts"])
        #expect(model.yourOtherApps.map(\.purpose) == ["calendar, gmail and drive"])
        #expect(model.onThisIphone.map(\.symbol) == ["calendar", "heart"])
        #expect(model.yourOtherApps.map(\.symbol) == ["envelope"])
        #expect(model.onThisIphone.map(\.state) == [.connected, .available])
        #expect(model.yourOtherApps.map(\.state) == [.available])
        // the founder's list leaves notion and github out; contacts waits for its drawing (Q1)
        let names = Set((model.onThisIphone + model.yourOtherApps).map(\.name))
        #expect(names.isDisjoint(with: ["notion", "github", "music", "contacts"]))
    }

    @Test("the meter is Paper's 1-of-6 with calendar connected")
    func meterStartsAtOneOfSix() {
        let model = make()
        #expect(model.knowsYou == Flows.KnowsYou(filled: 1, steps: 6))
        #expect(abs(model.knowsYou.fraction - 1.0 / 6) < 0.0001)
    }

    @Test("the meter's fraction stays in 0…1 and is empty with no steps")
    func meterFractionClamped() {
        #expect(Flows.KnowsYou(filled: 9, steps: 6).fraction == 1)
        #expect(Flows.KnowsYou(filled: -1, steps: 6).fraction == 0)
        #expect(Flows.KnowsYou(filled: 1, steps: 0).fraction == 0)
    }

    @Test("the words are Paper's, word for word")
    func copyIsPapers() {
        #expect(ConnectModel.title == "i'd love to get to know you.")
        #expect(ConnectModel.body == "each one sharpens your episodes. i read, never post.")
        #expect(ConnectModel.meterLabel == "knows you a little")
        #expect(ConnectModel.onThisIphoneLabel == "on this iPhone")
        #expect(ConnectModel.yourOtherAppsLabel == "your other apps")
        #expect(ConnectModel.continueTitle == "continue")
        #expect(ConnectModel.laterTitle == "later")
    }

    @Test("ON-6 sits at 55%, arriving from privacy's 48%")
    func progressRange() {
        #expect(ConnectModel.progress == FlowProgress(from: 0.48, to: 0.55))
    }

    // MARK: Connecting

    @Test("connect lands connected: the row says so, the meter steps, VoiceOver hears it once")
    func connectFillsTheMeter() async {
        let model = make()
        #expect(model.connections == 0)
        #expect(model.announcement == nil)
        await model.connect("apple_health")
        #expect(model.onThisIphone.map(\.state) == [.connected, .connected])
        #expect(model.knowsYou.filled == 2)
        #expect(model.connections == 1)
        #expect(model.announcement == "health connected. knows you a little.")
        #expect(model.phase == .ready)
        await model.connect("google")
        #expect(model.knowsYou.filled == 3)
        #expect(model.connections == 2)
        #expect(model.announcement == "google connected. knows you a little.")
    }

    @Test("a connected source isn't connected again; an unknown one does nothing")
    func connectOnlyAvailable() async {
        let data = SampleConnect()
        let model = make(data)
        await model.connect("apple_calendar")
        await model.connect("music")
        #expect(data.connectCalls == 0)
        #expect(model.connections == 0)
        await model.connect("apple_health")
        await model.connect("apple_health")
        #expect(data.connectCalls == 1)
        #expect(model.connections == 1)
    }

    @Test("a connect that doesn't land leaves the row and the meter as they were")
    func notConnectedLeavesTheRow() async {
        let data = SampleConnect(refuses: ["apple_health"])
        let model = make(data)
        await model.connect("apple_health")
        #expect(data.connectCalls == 1)
        #expect(model.onThisIphone.map(\.state) == [.connected, .available])
        #expect(model.knowsYou.filled == 1)
        #expect(model.connections == 0)
        #expect(model.announcement == nil)
        #expect(model.phase == .ready)
    }

    @Test("one connect at a time: a second tap while one is out asks nothing")
    func oneConnectAtATime() async {
        let data = HeldConnect()
        let model = make(data)
        let first = Task { await model.connect("apple_health") }
        await settle()
        #expect(model.phase == .connecting("apple_health"))
        await model.connect("google")
        await model.connect("apple_health")
        #expect(data.calls == 1)
        await data.land(.connected)
        await first.value
        #expect(model.phase == .ready)
        #expect(model.connections == 1)
        #expect(model.yourOtherApps.map(\.state) == [.available])
    }

    @Test("a connect that lands after the page was left changes nothing on it")
    func lateConnectAfterLeaving() async {
        let data = HeldConnect()
        let model = make(data)
        let first = Task { await model.connect("apple_health") }
        await settle()
        #expect(data.isWaiting)
        model.later()
        await data.land(.connected)
        await first.value
        #expect(model.phase == .left)
        #expect(model.connections == 0)
        #expect(model.announcement == nil)
        #expect(exits.done == [.later])
    }

    @Test("a source that stopped working or never finished can be connected again; connected and unknown can't")
    func connectableStates() async {
        let data = StubConnect([
            StubConnect.source("problem", .problem),
            StubConnect.source("connecting", .connecting),
            StubConnect.source("connected", .connected),
            StubConnect.source("unknown", .unknown),
        ])
        let model = make(data)
        for id in ["problem", "connecting", "connected", "unknown"] {
            await model.connect(id)
        }
        #expect(data.asked == ["problem", "connecting"])
    }

    @Test("while one connect is out, only that source's pill is live")
    func otherPillsWaitWhileConnecting() async {
        let data = HeldConnect()
        let model = make(data)
        let health = model.onThisIphone[1]
        let google = model.yourOtherApps[0]
        #expect(model.canConnect(health) && model.canConnect(google))
        let first = Task { await model.connect(health.id) }
        await settle()
        #expect(model.canConnect(health))
        #expect(model.canConnect(google) == false)
        await data.land(.notConnected)
        await first.value
        #expect(model.canConnect(google))
    }

    @Test("sources behind 'see all' aren't listed while its page isn't drawn")
    func seeAllNotListed() {
        let data = StubConnect([
            StubConnect.source("calendar", .connected),
            StubConnect.source("notion", .available, group: .seeAll),
            StubConnect.source("odd", .available, group: .unknown),
        ])
        let model = make(data)
        #expect(model.onThisIphone.map(\.id) == ["calendar"])
        #expect(model.yourOtherApps.isEmpty)
    }

    @Test("the meter's words follow its level, and every level says Paper's one line until Q2")
    func meterWordsPerLevel() {
        for level in [Flows.KnowsYou.Level.little, .better, .well, .unknown] {
            let model = make(StubConnect([], level: level))
            #expect(model.meterWords == "knows you a little")
        }
    }

    @Test("nothing connects after the page was left")
    func noConnectAfterLeaving() async {
        let data = SampleConnect()
        let model = make(data)
        model.back()
        await model.connect("apple_health")
        #expect(data.connectCalls == 0)
    }

    // MARK: Leaving

    @Test("continue appears at half a meter (3 of 6): not with calendar alone, not after one more, after two")
    func continueAppearsAtHalf() async {
        #expect(ConnectModel.continueAppearsAtMeter == 0.5)
        let model = make()
        #expect(model.showsContinue == false)
        await model.connect("apple_health")
        #expect(model.knowsYou.filled == 2)
        #expect(model.showsContinue == false)
        await model.connect("google")
        #expect(model.knowsYou.filled == 3)
        #expect(model.showsContinue)
    }

    @Test("before continue shows it does nothing; later always moves on")
    func continueHiddenDoesNothing() {
        let model = make()
        model.continueOn()
        #expect(exits.done.isEmpty)
        #expect(model.phase == .ready)
        model.later()
        #expect(exits.done == [.later])
    }

    @Test("continue and later each leave once, and both go on (founder decision 5)")
    func continueAndLater() async {
        let model = make()
        await model.connect("apple_health")
        await model.connect("google")
        model.continueOn()
        model.continueOn()
        model.later()
        model.back()
        #expect(exits.done == [.continued])
        #expect(exits.backs == 0)
        #expect(model.phase == .left)

        let laterExits = Exits()
        let other = ConnectModel(data: SampleConnect(), onDone: { laterExits.done.append($0) }, onBack: { laterExits.backs += 1 })
        other.later()
        other.continueOn()
        #expect(laterExits.done == [.later])
    }

    @Test("back leaves once, and nothing moves on after it")
    func backOnce() {
        let model = make()
        model.back()
        model.back()
        model.continueOn()
        model.later()
        #expect(exits.backs == 1)
        #expect(exits.done.isEmpty)
    }

    @Test("the launcher's ON-6 states: as Paper draws it, and every sample source connected (3 of 6)")
    func launcherState() {
        #expect(ConnectScenario.allCases.map(\.rawValue) == ["connect", "connect-3of6"])
        let full = make(SampleConnect(scenario: .connectAll))
        #expect(full.knowsYou.filled == 3)
        #expect(full.showsContinue)
        #expect((full.onThisIphone + full.yourOtherApps).allSatisfy { $0.state == .connected })
        #expect(make().knowsYou.filled == 1)
    }

    @Test("founder 26 Oct (#199): the onboarding back chevron at Paper's size; the lit primary button without its halo")
    func sharedPartsMatchPaper() {
        let back = RIconButton.onboardingBack {}
        #expect(back.symbol == "chevron.left")
        #expect(back.role == .inField)
        #expect(back.glyphScale == RIconButton.backChevronGlyphScale)
        // 11.3pt of SF's 14 at the default 0.82
        #expect(abs(RIconButton.backChevronGlyphScale - RSymbol.defaultGlyphScale * 11.3 / 14) < 0.005)
        #expect(RIconButton(symbol: "mic", label: "talk", role: .inField) {}.glyphScale == RSymbol.defaultGlyphScale)
        #expect(RButton.primaryHalo == false)
        // founder 27 Oct: the knows-you meter fills with ink, not blue
        #expect(RKnowsYouTrack.fill == RColor.inkDefault)
    }

    @Test("under Paper line boxes a one-line ink title is still 33 tall (214's pitch, not trimmed twice); SF text rounds to Paper's box")
    func paperLineBoxesOnRenderedText() {
        #expect(abs(Self.height(Text("i'd love to get to know you.").rText(.inkTitle)) - 33) <= 0.34)
        #expect(abs(Self.height(Text("each one sharpens your episodes.").rText(.textMd)) - 19) <= 0.34)
        #expect(abs(Self.height(Text("calendar").rText(.rowTitle)) - 23) <= 0.34)
    }

    /// The laid-out height of one line of text on the connect page's settings (Paper line boxes on,
    /// 3x), the way a screen measures it.
    private static func height(_ view: some View) -> CGFloat {
        let hosting = UIHostingController(rootView: view.environment(\.rPaperLineBoxes, true).environment(\.displayScale, 3))
        hosting.safeAreaRegions = []
        return hosting.sizeThatFits(in: CGSize(width: 400, height: 2000)).height
    }

    @Test("Paper's line boxes: whole points, measured against the line SwiftUI draws on whole pixels")
    func paperLineBoxes() {
        // SF 14 (16.707 tall) in Paper's 18.2 box: 19 on screen, so 1 above and 1 below on a 3x screen
        #expect(abs(RPaperLineBox.halfLeading(box: 18.2, natural: 16.707, scale: 3) - 1) < 0.0001)
        // the inky title (36.007 tall) in Paper's 33 box: trimmed to 33
        #expect(abs(RPaperLineBox.halfLeading(box: 30 * 1.1, natural: 36.007, scale: 3) - (33 - 36 - 1.0 / 3) / 2) < 0.0001)
        // 30 × 1.1 lands a hair over 33 and still counts as 33
        #expect(abs(RPaperLineBox.onPixels(16.707, scale: 3) - 17) < 0.0001)
        #expect(abs(RPaperLineBox.onPixels(17, scale: 3) - 17) < 0.0001)
        #expect(abs(RPaperLineBox.onPixels(16.707, scale: 0) - 16.707) < 0.0001)
    }
}
