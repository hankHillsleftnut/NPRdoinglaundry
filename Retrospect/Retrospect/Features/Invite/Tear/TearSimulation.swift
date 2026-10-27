//
//  TearSimulation.swift
//  TEAR.motion: the tear as a small physical model, from touch-down to rest. Pure and
//  deterministic: the same inputs at the same times give the same frames, so every phase can be
//  tested and filmed frame by frame. InviteStageController feeds it the finger and the clock and
//  the ticket draws its frames; the haptics fire from its events.
//
//  The model, in the order a real ticket does it:
//  1. Perforation: the tear front sticks at each paper bridge and slips to the next hole
//     (stick-slip detents, one click per hole). The first bridge holds longer (anticipation).
//  2. Flap: the torn length peels away as one curving sheet (TearCurve), its tip reaching the droop
//     angle, which grows with length^1.5 (a cantilever's sag) and lags the front on a spring.
//  3. Commit: past the threshold the front runs on by itself, accelerating (paper gives faster
//     once it has started), still stepping hole by hole, and holds at the last bridge.
//  4. Separation: the last bridge snaps (the rip). The stub falls (TearSeparation) and lands; the
//     body, no longer pulled by the stub's weight, recoils up and shakes once.
//
//  Only the finger-follow is linear (motion-system.md allows a 1:1 drag); everything else is a
//  design-system spring, gravity, or an ease.
//
import CoreGraphics
import Foundation

/// What happened on a frame, for haptics (and for the tests' record).
enum TearEvent: Equatable {
    case touchDown
    case tick(hole: Int)
    case springBack
    case commit
    case rip
    case land
}

struct TearSimulation {
    enum Phase: Equatable {
        case idle
        case dragging
        case springingBack
        case running(start: CGFloat, speed: Double, at: Double)
        case sealing
        case separated(at: Double)
    }

    /// The model's own step: 240 a second, so a display's frame rate never changes a result.
    static let step = 1.0 / 240

    let p: TearParameters
    let perforation: TearPerforation
    let perforationY: CGFloat
    let stubHeight: CGFloat
    let dropGap: CGFloat

    private(set) var phase: Phase = .idle
    private(set) var time = 0.0
    /// Where the finger (or, once committed, the run) is along the line, rubber-banded past the ends.
    private(set) var finger: CGFloat = 0
    private(set) var pull: CGFloat = 0
    private(set) var front: CGFloat = 0
    private(set) var tension = 0.0
    private(set) var events: [(TearEvent, Double)] = []
    /// The flap's tip angle (degrees, negative hangs down).
    private(set) var angle = 0.0
    private var tensionVelocity = 0.0
    private var angleVelocity = 0.0
    private var tilt = 0.0
    private var tiltVelocity = 0.0
    private var frontVelocity = 0.0
    private var lastTick = -1.0
    private var passed = 0
    private var separation: TearSeparation?
    private var landed = false
    /// The redeem answered while the front was still running: it snaps on reaching the last bridge.
    private var ripPending = false

    init(p: TearParameters = .tokens, width: CGFloat, perforationY: CGFloat, stubHeight: CGFloat, dropGap: CGFloat) {
        self.p = p
        perforation = TearPerforation(width: width)
        self.perforationY = perforationY
        self.stubHeight = stubHeight
        self.dropGap = dropGap
    }

    var holesPassed: Int {
        passed
    }

    var isSeparated: Bool {
        if case .separated = phase {
            return true
        }
        return false
    }

    var isRunning: Bool {
        if case .running = phase {
            return true
        }
        return false
    }

    /// Nothing will move until a new input: the clock may stop.
    var isAtRest: Bool {
        switch phase {
        case .idle: true
        case let .separated(at): separation.map { time - at > $0.settledAt && landed } ?? true
        case .sealing: isHangingStill
        default: false
        }
    }

    /// Hanging from the last bridge with every spring settled (a refused redeem leaves it so).
    private var isHangingStill: Bool {
        abs(angle + p.droopMax) < 0.01 && abs(angleVelocity) < 0.01 && abs(1 - tension) < 0.001 && abs(tensionVelocity) < 0.01 // literal-ok: settled tolerances
    }

    // MARK: Inputs

    mutating func touch(x: CGFloat, dy: CGFloat) {
        if phase == .idle || phase == .springingBack {
            phase = .dragging
            events.append((.touchDown, time))
        }
        guard phase == .dragging else { return }
        finger = TearMath(width: perforation.width).rawProgress(x: x) * perforation.width
        pull = min(max(dy, 0), TearMath.wander)
    }

    /// The finger lifted: commit past the threshold (or on a flick), else spring back.
    mutating func release(velocity: CGFloat) {
        guard phase == .dragging else { return }
        let progress = finger / perforation.width
        if TearMath.commits(progress: progress, velocity: velocity) {
            run(speed: Double(velocity))
        } else {
            springBack(velocity: Double(velocity))
        }
    }

    /// The finger lifted and the tear commits (the controller has decided): the run starts.
    mutating func commit(velocity: CGFloat) {
        guard phase == .dragging else { return }
        run(speed: Double(velocity))
    }

    /// "tear ticket" (VoiceOver, Switch Control): the run starts by itself from wherever the front is.
    mutating func autoRun() {
        guard phase == .idle || phase == .dragging || phase == .springingBack else { return }
        if phase != .dragging {
            events.append((.touchDown, time))
        }
        run(speed: 0)
    }

    private mutating func run(speed: Double) {
        phase = .running(start: max(finger, 0), speed: max(speed, p.runMinSpeed), at: time)
        events.append((.commit, time))
    }

    /// The tear came to nothing (released short, cancelled, or the redeem failed): whole again.
    mutating func springBack(velocity: Double = 0) {
        switch phase {
        case .dragging, .running, .sealing:
            phase = .springingBack
            frontVelocity = velocity
            ripPending = false
            events.append((.springBack, time))
        default:
            return
        }
    }

    /// The redeem answered: the last bridge snaps (on reaching it, if the front is still running).
    mutating func rip() {
        if isRunning {
            ripPending = true
            return
        }
        guard phase == .sealing else { return }
        separation = TearSeparation(
            p: p, width: perforation.width, perforationY: perforationY, stubHeight: stubHeight, dropGap: dropGap,
            pivotX: front, hangAngle: angle, hangTilt: tilt
        )
        phase = .separated(at: time)
        ripPending = false
        events.append((.rip, time))
    }

    // MARK: The clock

    /// Advance to `now` in exact steps. At rest nothing moves, so the clock simply jumps.
    mutating func advance(to now: Double) {
        if phase == .idle {
            time = max(time, now)
            return
        }
        while time + Self.step <= now {
            tick(Self.step)
        }
    }

    private mutating func tick(_ dt: Double) {
        time += dt
        switch phase {
        case .idle:
            return
        case .dragging:
            let result = perforation.front(finger: min(max(finger, 0), perforation.width), p)
            front = result.front
            p.tensionSpring.step(&tension, &tensionVelocity, toward: result.tension, dt: dt)
        case .springingBack:
            var value = Double(front)
            p.tensionSpring.step(&value, &frontVelocity, toward: 0, dt: dt)
            front = CGFloat(max(value, 0))
            finger = front
            p.tensionSpring.step(&tension, &tensionVelocity, toward: 0, dt: dt)
            if front < 0.5, abs(angle) < 0.05 { // literal-ok: whole again within half a point
                reset()
            }
        case let .running(start, speed, at):
            stepRun(start: start, speed: speed, at: at, dt: dt)
        case .sealing:
            p.tensionSpring.step(&tension, &tensionVelocity, toward: 1, dt: dt)
        case let .separated(at):
            if !landed, let separation, time - at >= separation.landsAt {
                landed = true
                events.append((.land, time))
            }
            return
        }
        stepFlap(dt)
        countHoles()
        if phase == .sealing, ripPending {
            rip()
        }
    }

    private mutating func stepRun(start: CGFloat, speed: Double, at: Double, dt: Double) {
        let elapsed = time - at
        let target = perforation.lastHold(p)
        let u = start + CGFloat(speed * elapsed + p.runAcceleration * elapsed * elapsed / 2)
        finger = min(u, target)
        let result = perforation.front(finger: finger, p)
        front = result.front
        p.tensionSpring.step(&tension, &tensionVelocity, toward: result.tension, dt: dt)
        if u >= target {
            phase = .sealing
        }
    }

    private mutating func reset() {
        front = 0
        finger = 0
        angle = 0
        angleVelocity = 0
        phase = .idle
        passed = 0
    }

    private mutating func stepFlap(_ dt: Double) {
        let length = Double(front / perforation.width)
        let droop = p.droopMax * pow(length, p.droopExponent) + p.pullMax * Double(pull / TearMath.wander) * length
        let target = phase == .springingBack ? 0 : -(phase == .sealing ? p.droopMax : droop)
        let spring = phase == .springingBack ? p.tensionSpring : p.flapSpring
        spring.step(&angle, &angleVelocity, toward: target, dt: dt)
        spring.step(&tilt, &tiltVelocity, toward: 0, dt: dt)
    }

    private mutating func countHoles() {
        let now = perforation.holesPassed(front: front)
        defer { passed = now }
        guard now > passed, phase != .springingBack else { return }
        if time - lastTick >= p.tickGap - 1e-9 { // literal-ok: float tolerance on the 40ms floor
            lastTick = time
            events.append((.tick(hole: now), time))
        }
    }

    // MARK: Outputs

    var stub: TearStubPose {
        if case let .separated(at) = phase, let separation {
            return separation.stub(at: time - at)
        }
        let center = CGPoint(x: perforation.width / 2, y: perforationY + stubHeight / 2)
        return TearStubPose(
            bendFront: front, bendAngle: angle, bendLength: front, anchor: center, angle: 0, tilt: tilt, lift: 1,
            offset: .zero, shadow: min(1, Double(front / perforation.width))
        )
    }

    var body: TearBodyPose {
        if case let .separated(at) = phase, let separation {
            return separation.body(at: time - at)
        }
        return TearBodyPose(y: phase == .sealing ? p.sag * tension : 0, angle: 0)
    }

    /// The frame the ticket draws.
    var frame: TearFrame {
        TearFrame(
            stub: stub, body: body, lean: phase == .dragging ? p.leanMax * tension : 0,
            hiddenHoles: isSeparated ? TearPerforation.holeCount : passed, separated: isSeparated
        )
    }

    /// The curve the flap hangs on now (the same one TearBend.metal draws).
    var curve: TearCurve {
        let pose = stub
        return TearCurve(front: pose.bendFront, pivotY: perforationY, angle: pose.bendAngle, length: pose.bendLength, exponent: p.curveExponent)
    }

    /// A still mid-tear (the launcher's `-Tear` proof frames): the finger held at `progress`, settled.
    static func still(progress: CGFloat, width: CGFloat, perforationY: CGFloat, stubHeight: CGFloat, dropGap: CGFloat) -> TearSimulation {
        var sim = TearSimulation(width: width, perforationY: perforationY, stubHeight: stubHeight, dropGap: dropGap)
        sim.touch(x: progress * width, dy: 0)
        sim.advance(to: 2) // literal-ok: long enough for the flap's settle spring
        return sim
    }
}
