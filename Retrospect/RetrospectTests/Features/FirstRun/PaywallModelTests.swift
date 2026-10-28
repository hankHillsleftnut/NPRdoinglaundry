import Foundation
@testable import Retrospect
import Testing

/// A paywall the test answers by hand: `choose` waits until `answer(_:)`; counts calls.
@MainActor
private final class HeldPaywall: Flows.Paywall {
    private var pending: CheckedContinuation<Flows.Purchase, Never>?
    private(set) var offers = 0
    private(set) var chosen: [Flows.Plan] = []
    var failsOffer = false

    func offer() async -> Result<Flows.Offer, Flows.Failure> {
        offers += 1
        return failsOffer ? .failure(Flows.Failure(.network)) : .success(SamplePaywall.offer)
    }

    func choose(_ plan: Flows.Plan) async -> Flows.Purchase {
        chosen.append(plan)
        return await withCheckedContinuation { pending = $0 }
    }

    func answer(_ purchase: Flows.Purchase) {
        pending?.resume(returning: purchase)
        pending = nil
    }

    var isAnswering: Bool {
        pending != nil
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PaywallModelTests {
    @MainActor
    private final class Exits {
        var choices: [PaywallModel.Choice] = []
    }

    private func make(_ paywall: any Flows.Paywall) -> (PaywallModel, Exits) {
        let exits = Exits()
        let model = PaywallModel(paywall: paywall) { exits.choices.append($0) }
        return (model, exits)
    }

    @Test("the plans load from the seam once, with Paper's prices and saving")
    func loadsOffer() async {
        let paywall = HeldPaywall()
        let (model, _) = make(paywall)
        #expect(model.phase == .loading)
        await model.load()
        await model.load()
        #expect(paywall.offers == 1)
        #expect(model.offer?.monthly.displayPrice == "$24.99")
        #expect(model.offer?.yearly.displayPrice == "$239.99")
        #expect(model.offer?.saving == "save 20%")
    }

    @Test("a failed load leaves the page empty and hands nothing on (no drawn failure state)")
    func failedLoad() async {
        let paywall = HeldPaywall()
        paywall.failsOffer = true
        let (model, exits) = make(paywall)
        await model.load()
        #expect(model.phase == .loading)
        #expect(model.offer == nil)
        await model.choose(.yearly)
        #expect(exits.choices.isEmpty)
    }

    @Test("either plan goes on once, as subscribed (dummy: the sample charges nothing)", arguments: [PaywallModel.Choice.yearly, .monthly])
    func choosesOnce(_ choice: PaywallModel.Choice) async {
        let paywall = SamplePaywall()
        let (model, exits) = make(paywall)
        await model.load()
        await model.choose(choice)
        await model.choose(choice)
        await model.choose(choice == .yearly ? .monthly : .yearly)
        #expect(exits.choices == [choice])
        #expect(model.phase == .left(choice))
        #expect(paywall.choices == 1)
    }

    @Test("the plan sent to the seam is the one tapped")
    func sendsTheTappedPlan() async {
        let paywall = HeldPaywall()
        let (model, exits) = make(paywall)
        await model.load()
        async let done: Void = model.choose(.monthly)
        while !paywall.isAnswering {
            await Task.yield()
        }
        #expect(paywall.chosen.map(\.period) == [.month])
        // a second tap while the seam answers does nothing
        await model.choose(.yearly)
        #expect(paywall.chosen.count == 1)
        paywall.answer(.subscribed)
        await done
        #expect(exits.choices == [.monthly])
    }

    @Test("cancelled or failed keeps the plans and hands nothing on", arguments: [Flows.Purchase.cancelled, .failed(Flows.Failure(.network))])
    func notSubscribed(_ purchase: Flows.Purchase) async {
        let paywall = HeldPaywall()
        let (model, exits) = make(paywall)
        await model.load()
        async let done: Void = model.choose(.yearly)
        while !paywall.isAnswering {
            await Task.yield()
        }
        paywall.answer(purchase)
        await done
        #expect(exits.choices.isEmpty)
        #expect(model.offer == SamplePaywall.offer)
    }

    @Test("play nudges the lit plan and never moves the page or the phase")
    func nudge() async {
        let (model, exits) = make(SamplePaywall())
        model.nudge()
        #expect(model.nudges == 0) // nothing on screen yet
        await model.load()
        let before = model.phase
        model.nudge()
        model.nudge()
        #expect(model.nudges == 2)
        #expect(model.phase == before)
        #expect(exits.choices.isEmpty)
    }

    @Test("the mini-player keeps Paper's words and line (founder 26 Oct night)")
    func teaseIsPaper() {
        #expect(PaywallModel.Tease.paper.title == "the week you started")
        #expect(PaywallModel.Tease.paper.subline == "your first episode · 4:24 left")
        #expect(PaywallModel.Tease.paper.progress == 0.6)
    }

    @Test("copy is Paper's, minus the two lines the founder removed")
    func copy() {
        #expect(PaywallPage.headline == "hear the rest, and one every week.")
        #expect(PaywallPage.links == ["restore", "privacy", "terms"])
        #expect(!PaywallPage.links.contains("not now"))
        #expect(Benefit.paper.map(\.title) == [
            "wake up to what moved", "see your life, connected", "ask your life anything",
            "know if you're on track", "a podcast about your week", "a journal that talks back",
        ])
        #expect(Benefit.paper.map(\.line) == [
            "a 4-minute brief, made from yesterday", "the people and threads you return to",
            "answers from your days, with sources", "your goals, checked against your real days",
            "every sunday, like the one you just heard", "talk or type; it asks what's next",
        ])
        #expect(Benefit.paper.map(\.turn) == [-6, 0, 5, 0, -5, 0])
        #expect(PlanButton.spoken(plan: SamplePaywall.offer.yearly, saving: "save 20%") == "$239.99 per year, save 20%")
        #expect(PlanButton.spoken(plan: SamplePaywall.offer.monthly, saving: nil) == "$24.99 per month")
    }

    @Test("the launcher's paywall states exist")
    func launcherStates() {
        #expect(PaywallScenario.allCases.map(\.rawValue) == ["paywall", "paywall-still", "paywall-nudge"])
    }

    @Test("the held launcher states keep the plans after a stray tap")
    func heldStatesKeepPlans() async {
        let (model, exits) = make(SamplePaywall(answer: .cancelled))
        await model.load()
        await model.choose(.yearly)
        #expect(exits.choices.isEmpty)
        #expect(model.offer == SamplePaywall.offer)
    }
}

struct NudgeRulesTests {
    @Test("Reduce Motion: the nudge doesn't move (the haptic alone)")
    func reduceMotion() {
        #expect(NudgeRules.moves(reduceMotion: false))
        #expect(!NudgeRules.moves(reduceMotion: true))
    }

    @Test("haptics: at most one per 80 ms (motion.duration.instant)")
    func hapticGate() {
        var rules = NudgeRules()
        let start = ContinuousClock.now
        let fired = [0, 40, 79, 80, 100, 400].map { rules.allowHaptic(at: start.advanced(by: .milliseconds($0))) }
        #expect(fired == [true, false, false, true, false, true])
    }

    @Test("one play tap gives one haptic: the nudge's, so the well's press haptic is off on the paywall")
    @MainActor
    func onePlayTapOneHaptic() {
        // the well would add haptic.press on the press, and the nudge adds haptic.select at its peak,
        // ~motion.duration.fast later (past the 80 ms gate): two per tap unless the well's is off
        #expect(PaywallPage.playTapPressHaptic == nil)
        var rules = NudgeRules()
        let tap = ContinuousClock.now
        let peak = tap.advanced(by: .seconds(RNumber.motionDurationFast))
        let fired = rules.allowHaptic(at: peak)
        #expect(fired)
    }

    @Test("PW-Q9: play on the paywall's little player tells VoiceOver what it does")
    @MainActor
    func playHint() {
        #expect(PaywallPage.playHint == "the rest comes with a plan")
    }
}
