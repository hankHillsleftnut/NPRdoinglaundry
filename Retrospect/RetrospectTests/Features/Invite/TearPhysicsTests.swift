import CoreGraphics
@testable import Retrospect
import Testing

/// TEAR.motion: the tear model is deterministic, steps hole by hole, peels along a curve (never a
/// rigid plate), never runs linear, and lands exactly where Paper's T4 puts the keepsake.
struct TearPhysicsTests {
    let perforation = TearPerforation(width: 354)
    let p = TearParameters.tokens

    private func simulation() -> TearSimulation {
        TearSimulation(p: p, width: 354, perforationY: 264, stubHeight: 125, dropGap: 72)
    }

    /// The script: touch, drag to 74% over 0.9 s, lift; rip 0.3 s after the commit.
    private func run(_ sim: inout TearSimulation, until end: Double) {
        var t = 0.0
        var ripDue: Double?
        while t < end {
            t += 1.0 / 240
            let finger = TearScript.finger(at: t, width: 354)
            if finger.down {
                sim.touch(x: finger.x, dy: finger.dy)
            } else if t >= TearScript.releaseAt, sim.phase == .dragging {
                sim.release(velocity: TearScript.releaseVelocity(width: 354))
            }
            sim.advance(to: t)
            if ripDue == nil, sim.phase != .dragging, sim.phase != .idle {
                ripDue = t + TearScript.redeem
            }
            if let due = ripDue, t >= due, sim.phase == .sealing {
                sim.rip()
            }
        }
    }

    private func separation(hang: Double = -11) -> TearSeparation {
        TearSeparation(p: p, width: 354, perforationY: 264, stubHeight: 125, dropGap: 72, pivotX: 330, hangAngle: hang, hangTilt: 0)
    }

    // MARK: Springs

    @Test("the springs are the design system's tokens, rest without drift, and settle overshoots about 5%")
    func springs() {
        #expect(TearSpring.settlePair.response == RNumber.motionSpringSettleResponse)
        #expect(TearSpring.snappyPair.damping == RNumber.motionSpringSnappyDamping)
        let rest = TearSpring.settlePair.state(from: 10, velocity: 0, at: 3)
        #expect(abs(rest.x) < 0.001)
        let samples = stride(from: 0.0, through: 1.5, by: 1.0 / 240).map { TearSpring.settlePair.state(from: -1, velocity: 0, at: $0).x }
        #expect((samples.max() ?? 0) < 0.07)
    }

    @Test("no tear spring is damped below the floor (pop's 0.6), whatever it asks for")
    func dampingFloor() {
        let loose = TearSpring(response: 0.3, damping: 0.2)
        #expect(loose.damping == RNumber.motionTearDampingFloor)
        // and so it never rings more than pop does: under 10% overshoot from a step
        let samples = stride(from: 0.0, through: 2, by: 1.0 / 240).map { loose.state(from: -1, velocity: 0, at: $0).x }
        #expect((samples.max() ?? 0) < 0.1)
        for spring in [TearSpring.snappyPair, .settlePair, .popPair, p.flapSpring, p.landingSpring, p.bodySpring] {
            #expect(spring.damping >= RNumber.motionTearDampingFloor)
        }
    }

    // MARK: Stick-slip

    @Test("the front sticks at a bridge, then slips to the next hole")
    func stickSlip() {
        let stops = perforation.stops
        let start = stops[3]
        let end = stops[4]
        let held = perforation.front(finger: start + (end - start) * 0.5, p)
        #expect(held.front < start + (end - start) * 0.25)
        #expect(held.tension > 0.8)
        let through = perforation.front(finger: start + (end - start) * 0.99, p)
        #expect(through.front > end - 0.5)
    }

    @Test("the first bridge holds longer: nothing tears for the first few points")
    func breakaway() {
        let first = perforation.stops[1]
        #expect(perforation.front(finger: first * 0.7, p).front < perforation.stops[0] + 2)
    }

    @Test("the front only moves forward with the finger and stays within a bridge of it")
    func monotonic() {
        var last: CGFloat = 0
        for u in stride(from: CGFloat(0), through: 354, by: 0.5) {
            let front = perforation.front(finger: u, p).front
            #expect(front >= last - 0.0001)
            #expect(front <= u + TearPerforation.notch + 0.0001)
            last = front
        }
    }

    // MARK: The curve

    private let curve = TearCurve(front: 300, pivotY: 264, angle: -11, length: 300)

    @Test("the joined paper right of the front is untouched, and the bend starts without a step")
    func curveJoined() {
        for x in stride(from: CGFloat(300), through: 354, by: 6) {
            for y in [CGFloat(264), 300, 389] {
                let placed = curve.place(CGPoint(x: x, y: y))
                #expect(abs(placed.x - x) < 0.0001 && abs(placed.y - y) < 0.0001)
            }
        }
        let justLeft = curve.place(CGPoint(x: 299.9, y: 330))
        #expect(abs(justLeft.x - 299.9) < 0.05 && abs(justLeft.y - 330) < 0.05)
    }

    @Test("from the joined point the flap curves continuously: the tangent and the droop only grow, to 11° at the tip")
    func curveMonotonic() {
        var lastTurn = 0.0
        var lastDrop: CGFloat = 0
        for s in stride(from: CGFloat(1), through: 300, by: 1) {
            let turn = curve.turn(at: s)
            let drop = curve.edge(at: s).height
            #expect(turn > lastTurn)
            #expect(drop > lastDrop)
            lastTurn = turn
            lastDrop = drop
        }
        #expect(abs(curve.tipAngle - 11) < 0.0001)
    }

    @Test("it is a curve, not a rigid plate: halfway along, the tangent has turned only part of the way")
    func curveNotRigid() {
        let half = curve.turn(at: 150) * 180 / .pi
        #expect(half > 11 * 0.5 && half < 11 * 0.95)
        // a plate turned to the tip's angle would hang the tip lower than the peeling paper does
        let tip = curve.edge(at: 300)
        let plate = tearRotate(CGSize(width: -300, height: 0), -11)
        #expect(tip.height < plate.height - 10)
        #expect(tip.height > 20)
    }

    @Test("the paper bends without stretching: the perforation keeps its length along the curve")
    func curveNoStretch() {
        var length: CGFloat = 0
        var last = curve.place(CGPoint(x: 300, y: 264))
        for x in stride(from: CGFloat(299), through: 0, by: -1) {
            let next = curve.place(CGPoint(x: x, y: 264))
            length += hypot(next.x - last.x, next.y - last.y)
            last = next
        }
        #expect(abs(length - 300) < 0.05)
    }

    @Test("while it hangs on the last bridge the flap's tip reaches the full droop, 11°")
    func hangsAtDroop() {
        var sim = simulation()
        run(&sim, until: 1.3)
        sim.advance(to: 2.5) // the redeem is slow: it hangs, settled
        #expect(sim.phase == .sealing)
        #expect(sim.isAtRest)
        #expect(abs(sim.curve.tipAngle - RNumber.motionTearDroopMax) < 0.1)
        #expect(abs(sim.stub.angle) < 0.0001) // all of it is bend: no rigid turn while joined
    }

    // MARK: The whole tear

    @Test("the same script gives the same frames")
    func deterministic() {
        var a = simulation()
        var b = simulation()
        run(&a, until: 2.4)
        run(&b, until: 2.4)
        #expect(a.stub == b.stub)
        #expect(a.events.map(\.1) == b.events.map(\.1))
    }

    @Test("one click per hole, never two within 40ms, then a rip and a landing in that order")
    func events() throws {
        var sim = simulation()
        run(&sim, until: 3)
        let times = sim.events.compactMap { event -> Double? in
            if case .tick = event.0 {
                return event.1
            }
            return nil
        }
        #expect(times.count >= 12)
        for (a, b) in zip(times, times.dropFirst()) {
            #expect(b - a >= RNumber.motionTearTickGap - 0.0001)
        }
        let kinds = sim.events.map(\.0)
        let rip = kinds.firstIndex(of: .rip)
        let land = kinds.firstIndex(of: .land)
        #expect(try rip != nil && land != nil && #require(rip) < #require(land))
    }

    @Test("the keepsake rests 72 below at Paper's -14.8°, flat and centred; the body at -2")
    func rest() {
        var sim = simulation()
        run(&sim, until: 4)
        #expect(abs(sim.stub.offset.height - 72) < 0.5)
        #expect(abs(sim.stub.offset.width) < 0.5)
        #expect(abs(sim.stub.angle - -14.8) < 0.1)
        #expect(abs(sim.stub.bendAngle) < 0.01)
        #expect(abs(sim.body.y - -2) < 0.1)
        #expect(sim.isAtRest)
    }

    @Test("the separation starts exactly where the hanging stub was (no jump on the rip frame)")
    func continuous() {
        let pose = separation().stub(at: 0)
        #expect(abs(pose.bendAngle - -11) < 0.0001)
        #expect(pose.bendLength == 330)
        #expect(abs(pose.angle) < 0.0001)
        #expect(abs(pose.offset.width) < 0.0001)
        #expect(abs(pose.offset.height) < 0.0001)
        // a frame later it has barely moved
        let next = separation().stub(at: 1.0 / 120)
        #expect(abs(next.offset.height) < 1 && abs(next.angle) < 1)
    }

    @Test("the fall accelerates (gravity) before the landing spring catches it: no linear segment")
    func gravity() {
        let dt = 1.0 / 60
        let y = (0 ..< 6).map { separation().centre(at: Double($0) * dt).height }
        let steps = zip(y, y.dropFirst()).map { $1 - $0 }
        for (a, b) in zip(steps, steps.dropFirst()) {
            #expect(b > a)
        }
    }

    @Test("a release before the threshold springs back to whole, with no clicks on the way back")
    func springBack() {
        var sim = simulation()
        var t = 0.0
        while t < 0.5 {
            t += 1.0 / 240
            sim.touch(x: CGFloat(t / 0.5) * 140, dy: 0)
            sim.advance(to: t)
        }
        let clicks = sim.events.count
        sim.release(velocity: 0)
        sim.advance(to: t + 1.5)
        #expect(sim.phase == .idle)
        #expect(sim.front == 0)
        #expect(sim.holesPassed == 0)
        #expect(!sim.events.dropFirst(clicks).contains {
            if case .tick = $0.0 {
                true
            } else {
                false
            }
        })
    }

    @Test("a redeem that answers mid-run snaps on reaching the last bridge, not before")
    func ripWaitsForTheLastBridge() {
        var sim = simulation()
        sim.advance(to: 0)
        sim.touch(x: 260, dy: 0)
        sim.advance(to: 0.4)
        sim.commit(velocity: 0)
        sim.advance(to: 0.42)
        #expect(sim.isRunning)
        sim.rip()
        #expect(!sim.isSeparated)
        sim.advance(to: 1)
        #expect(sim.isSeparated)
        // it snapped from the last bridge, holding the full droop
        #expect(sim.stub.bendFront > perforation.holes.last ?? 0)
    }

    @Test("the redeem failing while it hangs springs the paper back whole")
    func failedRedeem() {
        var sim = simulation()
        run(&sim, until: 1.3)
        #expect(sim.phase == .sealing)
        sim.springBack()
        sim.advance(to: 3)
        #expect(sim.phase == .idle)
        #expect(sim.frame.hiddenHoles == 0)
    }

    @Test("'tear ticket' runs the tear by itself, clicking hole by hole, to the last bridge")
    func autoRun() {
        var sim = simulation()
        sim.advance(to: 0)
        sim.autoRun()
        sim.advance(to: 1.5)
        #expect(sim.phase == .sealing)
        #expect(sim.holesPassed == TearPerforation.holeCount)
        #expect(sim.events.filter {
            if case .tick = $0.0 {
                true
            } else {
                false
            }
        }.count >= 6)
    }

    @Test("pulled below the line, the flap still never droops past the founder's 11° tip")
    func droopClamped() {
        var sim = simulation()
        sim.advance(to: 0)
        for frame in 1 ... 240 {
            sim.touch(x: 340 * CGFloat(frame) / 240, dy: TearMath.wander)
            sim.advance(to: Double(frame) / 240)
        }
        sim.advance(to: 3)
        #expect(sim.curve.tipAngle <= RNumber.motionTearDroopMax + 0.001)
        #expect(sim.curve.tipAngle > RNumber.motionTearDroopMax - 0.5)
    }

    @Test("nothing flashes: at 60 fps every shadow and pose moves a little each frame, through the whole tear")
    func shadowsContinuous() {
        var sim = simulation()
        var last: TearFrame?
        var worst = (group: 0.0, piece: 0.0, shade: 0.0, offset: 0.0, angle: 0.0)
        var t = 0.0
        var ripDue: Double?
        while t < 3 {
            for _ in 0 ..< 4 { // the script at 240 Hz, read at 60 fps
                t += 1.0 / 240
                let finger = TearScript.finger(at: t, width: 354)
                if finger.down {
                    sim.touch(x: finger.x, dy: finger.dy)
                } else if t >= TearScript.releaseAt, sim.phase == .dragging {
                    sim.release(velocity: TearScript.releaseVelocity(width: 354))
                }
                sim.advance(to: t)
                if ripDue == nil, sim.isRunning {
                    ripDue = t + TearScript.redeem
                }
                if let due = ripDue, t >= due {
                    sim.rip()
                }
            }
            let frame = sim.frame
            if let last {
                worst.group = max(worst.group, abs((1 - frame.apart) - (1 - last.apart)))
                worst.piece = max(worst.piece, abs(frame.apart - last.apart))
                let shade = { (f: TearFrame) in f.stub.shadow * 0.6 * (1 - f.apart) }
                worst.shade = max(worst.shade, abs(shade(frame) - shade(last)))
                worst.offset = max(worst.offset, abs(frame.stub.offset.height - last.stub.offset.height))
                worst.angle = max(worst.angle, abs(frame.stub.angle - last.stub.angle))
            }
            last = frame
        }
        #expect(sim.isSeparated)
        // the hand-over takes the whole fall (a smoothstep): never more than 15% of a shadow in one frame
        #expect(worst.group < 0.15 && worst.piece < 0.15)
        #expect(worst.shade < 0.05)
        // and the stub itself never jumps: the fall's fastest frame stays a few points
        #expect(worst.offset < 12 && worst.angle < 3)
    }

    @Test("back from a pause the app replays at most a quarter second, not the whole time away")
    func catchUp() {
        var sim = simulation()
        sim.advance(to: 0)
        sim.autoRun() // the app goes away mid-run, for a minute
        sim.advance(to: 60, catchUp: TearSimulation.catchUp)
        // only the last quarter second was stepped: no click from the minute away was replayed
        let clicks = sim.events.filter {
            if case .tick = $0.0 {
                true
            } else {
                false
            }
        }
        #expect(!clicks.isEmpty)
        #expect(clicks.allSatisfy { $0.1 >= 60 - TearSimulation.catchUp - TearSimulation.step })
        #expect(sim.time >= 60 - TearSimulation.step)
    }

    @Test("the run speeds up: every step forward is longer than the one before (no linear run)")
    func runAccelerates() {
        var sim = simulation()
        sim.advance(to: 0)
        sim.touch(x: 260, dy: 0)
        sim.advance(to: 0.4)
        sim.commit(velocity: 0)
        var fingers: [CGFloat] = []
        for frame in 1 ... 8 {
            sim.advance(to: 0.4 + Double(frame) / 240)
            fingers.append(sim.finger)
        }
        let steps = zip(fingers, fingers.dropFirst()).map { $1 - $0 }
        for (a, b) in zip(steps, steps.dropFirst()) {
            #expect(b > a)
        }
    }
}
