//
//  TearSeparation.swift
//  TEAR.motion: what the ticket looks like on a frame (the poses), and everything after the rip as
//  a closed-form function of time: the stub falls under gravity and air drag, rocks once, springs
//  flat (the peel's curve lets go), turns to Paper's resting angle and lands; the body recoils.
//
import CoreGraphics
import Foundation

/// The stub as one sheet, applied in this order: the peel's curve (`TearCurve`: left of `bendFront`
/// the paper bends until its tip reaches `bendAngle`, over `bendLength`), the x-axis rock (`tilt`),
/// the lift (scale), the rigid turn `angle` about `anchor` (its centre), then `offset`.
struct TearStubPose: Equatable {
    var bendFront: CGFloat
    var bendAngle: Double
    var bendLength: CGFloat
    var anchor: CGPoint
    var angle: Double
    var tilt: Double
    var lift: Double
    var offset: CGSize
    /// 0…1, the soft shadow under the torn edge while it hangs.
    var shadow: Double
}

struct TearBodyPose: Equatable {
    var y: Double
    var angle: Double
}

/// One frame of the tear, as the ticket draws it.
struct TearFrame: Equatable {
    var stub: TearStubPose
    var body: TearBodyPose
    /// The whole ticket leans toward the finger while a bridge holds (points).
    var lean: Double
    var hiddenHoles: Int
    var separated: Bool
    /// 0 while the stub is joined, easing to 1 as it lands: the shadow hands over from the whole
    /// ticket's (one shadow round both pieces) to each piece's own, so no shadow ever pops.
    var apart: Double
    /// Whole and still: nothing torn (the page draws the same paper as before the touch).
    var whole: Bool
}

/// Everything after the rip, from the hanging pose, as a function of time.
struct TearSeparation: Equatable {
    let p: TearParameters
    let width: CGFloat
    let perforationY: CGFloat
    let stubHeight: CGFloat
    let dropGap: CGFloat
    /// The last bridge (the pivot it hung from).
    let pivotX: CGFloat
    /// The hanging flap's tip angle (the curve's end tangent).
    let hangAngle: Double
    let hangTilt: Double
    /// Fixed at the rip, so computed once (the fall reads them every frame).
    let hangChord: Double
    let startOffset: CGSize
    let handOff: (t: Double, v: Double)
    private(set) var landsAt: Double
    private(set) var settledAt: Double

    init(
        p: TearParameters, width: CGFloat, perforationY: CGFloat, stubHeight: CGFloat, dropGap: CGFloat,
        pivotX: CGFloat, hangAngle: Double, hangTilt: Double
    ) {
        self.p = p
        self.width = width
        self.perforationY = perforationY
        self.stubHeight = stubHeight
        self.dropGap = dropGap
        self.pivotX = pivotX
        self.hangAngle = hangAngle
        self.hangTilt = hangTilt
        let center = CGPoint(x: width / 2, y: perforationY + stubHeight / 2)
        let curve = TearCurve(front: pivotX, pivotY: perforationY, angle: hangAngle, length: pivotX, exponent: p.curveExponent)
        hangChord = curve.chordAngle(at: pivotX - center.x)
        let toCenter = CGSize(width: center.x - pivotX, height: center.y - perforationY)
        let turned = tearRotate(toCenter, hangChord)
        startOffset = CGSize(width: turned.width - toCenter.width, height: turned.height - toCenter.height)
        let fall = TearFall(gravity: p.gravity, drag: p.airDrag)
        let t = fall.time(toCover: Double(dropGap - startOffset.height) * p.freeFallShare, velocity: p.ripKick)
        handOff = (t, fall.state(velocity: p.ripKick, at: t).v)
        landsAt = 0
        settledAt = 0
        landsAt = findLanding()
        settledAt = findRest()
    }

    static func == (a: TearSeparation, b: TearSeparation) -> Bool {
        a.p == b.p && a.width == b.width && a.perforationY == b.perforationY && a.stubHeight == b.stubHeight
            && a.dropGap == b.dropGap && a.pivotX == b.pivotX && a.hangAngle == b.hangAngle && a.hangTilt == b.hangTilt
    }

    /// The stub's centre (the keepsake rotates about it).
    var center: CGPoint {
        CGPoint(x: width / 2, y: perforationY + stubHeight / 2)
    }

    /// The hanging curve on the rip frame.
    var hangCurve: TearCurve {
        TearCurve(front: pivotX, pivotY: perforationY, angle: hangAngle, length: pivotX, exponent: p.curveExponent)
    }

    // `hangChord` is the rigid turn about the pivot that puts the centre's column where the curve has
    // it (the sheet's overall angle on the rip frame, from which it turns to rest); `startOffset` makes
    // "rotate about the centre" equal "rotate about the pivot" at the snap; `handOff` is when free fall
    // hands over to the landing spring.

    private var fall: TearFall {
        TearFall(gravity: p.gravity, drag: p.airDrag)
    }

    /// Where the stub's centre has moved to (from where it sits joined): gravity and drag, then the
    /// landing spring down; the settle spring and the flutter's sway across.
    func centre(at t: Double) -> CGSize {
        let start = startOffset
        let drop = Double(dropGap - start.height)
        let hand = handOff
        let y: Double
        if t < hand.t {
            y = Double(start.height) + fall.state(velocity: p.ripKick, at: t).y
        } else {
            let land = p.landingSpring.state(from: -drop * (1 - p.freeFallShare), velocity: hand.v, at: t - hand.t)
            y = Double(dropGap) + land.x
        }
        let x = p.landingSpring.state(from: Double(start.width), velocity: 0, at: t).x
            + p.flutter * TearSpring.popPair.state(from: 0, velocity: p.flutterSwayKick, at: t).x
        return CGSize(width: x, height: y)
    }

    func stub(at t: Double) -> TearStubPose {
        let moved = centre(at: t)
        let chord = hangChord
        let angle = p.restAngle + p.angleSpring.state(from: chord - p.restAngle, velocity: p.spinKick, at: t).x
            + p.flutter * TearSpring.popPair.state(from: 0, velocity: p.flutterSpinKick, at: t).x
        let tilt = TearSpring.popPair.state(from: hangTilt, velocity: p.flutter * p.flutterTiltKick, at: t).x
        let lift = TearSpring.popPair.state(from: 0, velocity: p.liftKick, at: t).x
        // free, the paper springs flat (snappy) while the rigid turn takes over the share of the angle the
        // curve held, so the sheet as a whole follows the fall exactly: final = C + R(angle)(s - C) + (x, y)
        let relax = TearSpring.snappyPair.state(from: 1, velocity: 0, at: t).x
        let rigid = angle - chord * relax
        let pivot = CGPoint(x: pivotX, y: perforationY)
        let toCenter = CGSize(width: center.x - pivot.x, height: center.y - pivot.y)
        let a = tearRotate(toCenter, chord * relax + rigid)
        let b = tearRotate(CGSize(width: -toCenter.width, height: -toCenter.height), rigid)
        let offset = CGSize(width: Double(moved.width) - a.width - b.width, height: Double(moved.height) - a.height - b.height)
        return TearStubPose(
            bendFront: pivotX, bendAngle: hangAngle * relax, bendLength: pivotX, anchor: center, angle: rigid,
            tilt: tilt, lift: 1 + lift, offset: offset, shadow: Double(pivotX / width)
        )
    }

    /// How far the shadow has handed over to the pieces: a smoothstep over the fall, done as it lands.
    func apart(at t: Double) -> Double {
        let share = min(max(t / max(landsAt, TearSimulation.step), 0), 1)
        return share * share * (3 - 2 * share) // literal-ok: smoothstep
    }

    func body(at t: Double) -> TearBodyPose {
        let y = p.bodyRest + p.bodySpring.state(from: p.sag - p.bodyRest, velocity: p.recoil * p.recoilKick, at: t).x
        let angle = p.bodySpring.state(from: 0, velocity: p.recoil * p.shakeKick, at: t).x
        return TearBodyPose(y: y, angle: angle)
    }

    /// When the stub has come to rest (within half a point and a tenth of a degree).
    private func findRest() -> Double {
        var t = 0.0
        let rest = stub(at: 10)
        while t < 3 {
            let pose = stub(at: t)
            if abs(pose.offset.height - rest.offset.height) < 0.5, abs(pose.angle - rest.angle) < 0.1,
               abs(pose.offset.width) < 0.5, abs(pose.tilt) < 0.2, abs(pose.bendAngle) < 0.1 {
                return t
            }
            t += 1.0 / 120
        }
        return t
    }

    /// The frame the stub lands: the first time it reaches its resting height (the landing tap).
    private func findLanding() -> Double {
        var t = handOff.t
        while t < 2 {
            if centre(at: t).height >= dropGap {
                return t
            }
            t += 1.0 / 240
        }
        return t
    }
}
