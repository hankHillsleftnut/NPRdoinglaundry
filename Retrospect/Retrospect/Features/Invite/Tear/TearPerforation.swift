//
//  TearPerforation.swift
//  TEAR.motion: the tear's dials (every one a `motion.tear.*` token) and the perforation the front
//  runs along: where the holes are, and how the front sticks at each paper bridge and slips to the
//  next hole (stick-slip, one click per hole).
//
import CoreGraphics
import Foundation

/// Every number the tear moves by. The defaults are the tokens; the lab and the tests may dial them.
struct TearParameters: Equatable {
    // Perforation: stick-slip per bridge.
    var catchShare = RNumber.motionTearCatchShare
    var catchGive = RNumber.motionTearCatchGive
    var breakawayCatch = RNumber.motionTearBreakawayCatch
    var breakawayGive = RNumber.motionTearBreakawayGive

    // The flap while tearing: a curve whose tip reaches `droopMax`.
    var droopMax = RNumber.motionTearDroopMax
    var droopExponent = RNumber.motionTearDroopExponent
    var curveExponent = RNumber.motionTearCurveExponent
    var pullMax = RNumber.motionTearPullMax
    var flapSpring = TearSpring.settlePair
    var leanMax = Double(RDimension.motionTearLeanMax)
    var tensionSpring = TearSpring.snappyPair

    // Commit: the front runs on by itself.
    var runMinSpeed = RNumber.motionTearRunMinSpeed
    var runAcceleration = RNumber.motionTearRunAcceleration

    // Separation.
    var gravity = RNumber.motionTearGravity
    var airDrag = RNumber.motionTearAirDrag
    var freeFallShare = RNumber.motionTearFreeFallShare
    var ripKick = RNumber.motionTearRipKick
    var restAngle = RNumber.motionTearRestAngle
    var angleSpring = TearSpring.settlePair
    var spinKick = RNumber.motionTearSpinKick
    var flutter = RNumber.motionTearFlutter
    var flutterTiltKick = RNumber.motionTearFlutterTiltKick
    var flutterSpinKick = RNumber.motionTearFlutterSpinKick
    var flutterSwayKick = RNumber.motionTearFlutterSwayKick
    var liftKick = RNumber.motionTearLiftKick
    var landingSpring = TearSpring.settlePair

    // The body.
    var sag = Double(RDimension.motionTearSag)
    var recoil = RNumber.motionTearRecoil
    var recoilKick = RNumber.motionTearRecoilKick
    var shakeKick = RNumber.motionTearShakeKick
    var bodyRest = Double(RDimension.motionTearBodyRest)
    var bodySpring = TearSpring.settlePair

    /// At most one click per this long (the board's 40ms).
    var tickGap = RNumber.motionTearTickGap

    static let tokens = TearParameters()
}

/// Where the holes are and how the front moves through the bridges between them. Measures are the
/// board's: notches r10 at the edges, 21 holes of 6 spread between 20pt paddings.
struct TearPerforation: Equatable {
    let width: CGFloat
    static let holeCount = TearMath.holeCount
    static let notch: CGFloat = 10 // literal-ok: board 2HXP-0
    static let firstHole: CGFloat = 23 // literal-ok: 20 padding + half a 6pt hole

    var holes: [CGFloat] {
        let span = width - 2 * Self.firstHole
        return (0 ..< Self.holeCount).map { Self.firstHole + span * CGFloat($0) / CGFloat(Self.holeCount - 1) }
    }

    /// The bridges' ends: notch edge, each hole, notch edge (22 bridges).
    var stops: [CGFloat] {
        [Self.notch] + holes + [width - Self.notch]
    }

    /// The front for a finger at `u` (points from the left notch), and how hard the bridge is holding (0…1).
    func front(finger u: CGFloat, _ p: TearParameters) -> (front: CGFloat, tension: Double) {
        let stops = stops
        guard u > stops[0] else { return (0, 0) }
        guard u < stops[stops.count - 1] else { return (width, 0) }
        var index = 0
        while index < stops.count - 2, u >= stops[index + 1] {
            index += 1
        }
        let start = stops[index]
        let end = stops[index + 1]
        let share = Double((u - start) / (end - start))
        let hold = index == 0 ? p.breakawayCatch : p.catchShare
        let give = index == 0 ? p.breakawayGive : p.catchGive
        let (g, tension) = Self.detent(share, hold: hold, give: give)
        return (start + CGFloat(g) * (end - start), tension)
    }

    /// Stick, then slip: creeps `give` while the finger covers `hold`, then snaps through on an ease-out.
    static func detent(_ share: Double, hold: Double, give: Double) -> (Double, Double) {
        if share < hold {
            return (give * share / hold, share / hold)
        }
        let slip = (share - hold) / (1 - hold)
        let eased = 1 - pow(1 - slip, 3) // literal-ok: cubic ease-out, the slip
        return (give + (1 - give) * eased, (1 - eased) * (1 - slip))
    }

    /// The finger position where the last bridge holds (the commit run stops here, sealing).
    func lastHold(_ p: TearParameters) -> CGFloat {
        let stops = stops
        let start = stops[stops.count - 2]
        let end = stops[stops.count - 1]
        return start + CGFloat(p.catchShare) * (end - start) * 0.98 // literal-ok: just short of the slip
    }

    func holesPassed(front: CGFloat) -> Int {
        holes.filter { $0 <= front }.count
    }
}
