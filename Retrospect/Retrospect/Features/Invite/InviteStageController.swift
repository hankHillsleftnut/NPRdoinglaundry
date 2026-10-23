//
//  InviteStageController.swift
//  PI2.1–PI2.4: the animated half of the moment (what moves with a finger or a clock), apart from
//  the model (what is true). It owns the print progress, the tear point and its ticks, the Reduce
//  Motion hold, and the rumble. Nothing here talks to a door: the model decides what a tear came to.
//
import SwiftUI

@MainActor @Observable
final class InviteStageController {
    /// 0 = inside the printer, 1 = printed.
    private(set) var printProgress: CGFloat
    private(set) var slotPrinting = false
    /// Where the tear is along the perforation, 0...1.
    private(set) var tearProgress: CGFloat
    private(set) var held = false
    /// One per hole passed (throttled) and one on touch-down: the `select` haptic.
    private(set) var ticks = 0
    /// Reduce Motion: how far the press-and-hold has filled the line.
    private(set) var holdProgress: CGFloat = 0
    /// A settle tick when the print lands.
    private(set) var landings = 0

    let model: InviteModel
    @ObservationIgnored private var ticker = HoleTicker()
    @ObservationIgnored private let start = ContinuousClock.now
    @ObservationIgnored private let rumble = TicketRumble()
    @ObservationIgnored private var dragging = false
    /// The finger wandered off the line: the drag has ended as a release and stays ended until the finger lifts.
    @ObservationIgnored private var released = false
    @ObservationIgnored private var holding: Task<Void, Never>?
    /// A hold completed and the finger is still down: no new hold until it lifts (a fast offline
    /// failure would otherwise start, and commit, another one under the same finger).
    @ObservationIgnored private var holdSpent = false
    /// A still for proof (the launcher holds mid-print or mid-tear): nothing moves it on.
    @ObservationIgnored private let frozen: Bool
    @ObservationIgnored private let sleep: @Sendable (Duration) async -> Void

    /// The print's own curve: starts gently, ends flat (`motion.curve.print` over `motion.duration.print`, FR0.1).
    static let printCurve = Animation.timingCurve(0.3, 0, 0.2, 1, duration: 1.8) // literal-ok: FR0.1 token, not yet generated
    /// The slot readies before the paper moves (the board's 0.45 s between sign-in and the rise).
    static let slotLead: Duration = .milliseconds(450)

    init(
        model: InviteModel, printStill: CGFloat? = nil, tear: CGFloat = 0,
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.model = model
        self.sleep = sleep
        tearProgress = tear
        frozen = printStill != nil || tear > 0
        if let printStill {
            printProgress = printStill
            slotPrinting = printStill < 1
        } else {
            switch model.phase {
            case .promise, .signingIn, .waiting: printProgress = 0
            case .printing: printProgress = model.printAnimates ? 0 : 1
            case .refused: printProgress = model.printAnimates ? 0 : 1
            default: printProgress = 1
            }
        }
    }

    // MARK: The print

    /// The phase changed (or the page appeared): start the print if it is one.
    func phaseChanged(reduceMotion: Bool) {
        guard !frozen else { return }
        switch model.phase {
        case .printing, .refused:
            if model.printAnimates, printProgress < 1, !slotPrinting {
                startPrint(reduceMotion: reduceMotion)
            }
        case .ready, .typed:
            if printProgress < 1, !slotPrinting {
                printProgress = 1
            }
            if model.phase == .ready, tearProgress > 0, !dragging, !isCommitted {
                springBack()
            }
        case .promise, .signingIn, .waiting:
            printProgress = 0
        default:
            break
        }
    }

    private var isCommitted: Bool {
        model.phase == .sealing || model.phase == .torn || model.phase == .youreIn
    }

    func startPrint(reduceMotion: Bool) {
        if reduceMotion {
            // no rise: the ticket fades in under the slot and the rumble plays through the fade
            slotPrinting = true
            rumble.start()
            withAnimation(RMotion.standard(RNumber.motionDurationFast), completionCriteria: .logicallyComplete) {
                printProgress = 1
            } completion: { [weak self] in self?.printLanded() }
            return
        }
        slotPrinting = true
        Task { [weak self] in
            try? await Task.sleep(for: Self.slotLead)
            guard let self, slotPrinting else { return }
            rumble.start()
            withAnimation(Self.printCurve, completionCriteria: .logicallyComplete) {
                printProgress = 1
            } completion: { [weak self] in self?.printLanded() }
        }
    }

    /// The print's animation finished. After `finishPrintNow()` it already landed, silently: no
    /// settle tick and no second `skipPrint()`.
    func printLanded() {
        guard slotPrinting else { return }
        rumble.stop()
        slotPrinting = false
        landings += 1
        model.skipPrint()
    }

    /// Back from the background mid-print: it is simply done, with no rumble and no replay.
    func finishPrintNow() {
        guard !frozen, slotPrinting || printProgress < 1, model.isPrinting else { return }
        rumble.stop()
        printProgress = 1
        slotPrinting = false
        model.skipPrint()
    }

    // MARK: The tear (a drag)

    /// A finger on the handle: `x` along the ticket, `dy` off the line.
    func dragChanged(x: CGFloat, dy: CGFloat, width: CGFloat) {
        guard model.phase == .ready, !released else { return }
        if !dragging {
            dragging = true
            held = true
            ticks += 1
            model.tearTouchedDown()
        }
        guard TearMath.isTearing(dy: dy) else {
            // more than 44pt off the line: the drag ends as a release, and stays ended until the finger lifts
            dragEnded(x: x, velocity: 0, width: width)
            released = true
            return
        }
        let math = TearMath(width: width)
        let progress = math.progress(x: x)
        tearProgress = progress
        if ticker.tick(progress: progress, at: .now - start) {
            ticks += 1
        }
        if progress > 0, TearMath.hiddenHoles(progress: progress) >= 1 {
            model.keepGoing = true
        }
    }

    func dragEnded(x: CGFloat, velocity: CGFloat, width: CGFloat) {
        released = false // the lift (or the wander's own release, which sets it again just after)
        guard dragging else { return }
        dragging = false
        held = false
        let progress = TearMath(width: width).progress(x: x)
        if model.phase == .ready, TearMath.commits(progress: progress, velocity: velocity) {
            commit()
        } else {
            springBack()
            model.tearAbandoned()
        }
    }

    /// The system took the gesture (a call, the app backgrounding): whole again.
    func dragCancelled() {
        released = false
        guard dragging else { return }
        dragging = false
        held = false
        springBack()
        model.tearAbandoned()
    }

    private func commit() {
        withAnimation(RMotion.snappy) { tearProgress = 1 }
        Task { await model.commitTear() }
    }

    func springBack() {
        withAnimation(RMotion.snappy) {
            tearProgress = 0
            holdProgress = 0 // a failed hold's fill empties too, so the next hold is seen filling
        }
        ticker.reset()
    }

    /// Whether "tear ticket" is offered to VoiceOver and Switch Control.
    var canTear: Bool {
        model.phase == .ready
    }

    /// "tear ticket" (VoiceOver, Switch Control): the whole sequence without a drag.
    func tearByAction() async {
        guard canTear else { return }
        model.tearTouchedDown()
        withAnimation(RMotion.snappy) { tearProgress = 1 }
        await model.commitTear()
    }

    // MARK: Reduce Motion: press and hold

    func holdBegan() {
        guard model.phase == .ready, holding == nil, !holdSpent else { return }
        held = true
        ticks += 1
        model.tearTouchedDown()
        withAnimation(RMotion.move(0.6)) { holdProgress = 1 } // literal-ok: the board's 0.6 s hold
        holding = Task { [weak self, sleep] in
            // select at each third of the hold; the last third completes it, so the tear does not
            // wait for the finger to lift
            for _ in 0 ..< 2 {
                await sleep(.milliseconds(200))
                guard !Task.isCancelled else { return }
                self?.ticks += 1
            }
            await sleep(.milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.holdReleased(completed: true)
        }
    }

    func holdReleased(completed: Bool) {
        if !completed {
            holdSpent = false // the finger lifted (or the scene left): the next touch may hold again
        }
        guard holding != nil else { return }
        holding?.cancel()
        holding = nil
        held = false
        if completed {
            holdSpent = true
            tearProgress = 1
            Task { await model.commitTear() }
        } else {
            withAnimation(RMotion.exit(RNumber.motionDurationPopoverExit)) { holdProgress = 0 }
        }
    }
}
