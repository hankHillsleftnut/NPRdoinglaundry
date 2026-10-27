//
//  TearMath.swift
//  PI2.2: the tear's arithmetic, pure so it can be tested. Where the finger is along the
//  perforation, how far the stub has torn, which holes it has passed, when a release commits,
//  and when a tick may fire. The numbers are the founder's board (docs/team/flows/first-run/views.md).
//
import CoreGraphics
import Foundation

struct TearMath: Equatable {
    /// The ticket's width: the tear runs along it, left to right.
    var width: CGFloat

    /// 21 holes between the notches (C41.3).
    static let holeCount = 21
    /// Release past this share of the line commits (`motion.tear.threshold`).
    static let threshold = CGFloat(RNumber.motionTearThreshold)
    /// A rightward flick faster than this commits (`motion.tear.flickVelocity`), in points a second.
    static let flickVelocity = CGFloat(RNumber.motionTearFlickVelocity)
    /// The stub's torn length droops up to this many degrees (`motion.tear.droopMax`; under TEAR.motion the
    /// flap's tip reaches it along a curve, TearCurve).
    static let droopDegrees = RNumber.motionTearDroopMax
    /// The finger may wander this far above or below the line before the drag ends as a release.
    static let wander = RDimension.motionTearWander
    /// At most one tick per this long on a fast drag (the board's rule, `motion.tear.tickGap`).
    static let tickGap: Duration = .milliseconds(Int((RNumber.motionTearTickGap * 1000).rounded())) // literal-ok: seconds to milliseconds

    /// The tear point's share of the line for a finger at `x` (0 is the left notch). Past either
    /// end the movement scales by `motion.gesture.rubberBand`.
    func rawProgress(x: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let share = x / width
        let band = CGFloat(RNumber.motionGestureRubberBand)
        if share < 0 {
            return share * band
        }
        if share > 1 {
            return 1 + (share - 1) * band
        }
        return share
    }

    /// What the ticket shows: the rubber-banded value held to the line.
    func progress(x: CGFloat) -> CGFloat {
        min(max(rawProgress(x: x), 0), 1)
    }

    /// Whether a release at `progress`, moving `velocity` points a second, commits the tear.
    static func commits(progress: CGFloat, velocity: CGFloat) -> Bool {
        progress >= threshold || velocity > flickVelocity
    }

    /// The holes the tear has passed (they become the torn edge).
    static func hiddenHoles(progress: CGFloat) -> Int {
        let clamped = min(max(progress, 0), 1)
        return min(Int((clamped * CGFloat(holeCount)).rounded(.down)), holeCount)
    }

    /// How far the torn length of the stub has drooped, in degrees.
    static func droop(progress: CGFloat) -> Double {
        droopDegrees * Double(min(max(progress, 0), 1))
    }

    /// Whether a finger `dy` away from the line is still tearing.
    static func isTearing(dy: CGFloat) -> Bool {
        abs(dy) <= wander
    }
}

/// One tick each time the tear passes a hole, never faster than one per 40ms.
struct HoleTicker: Equatable {
    private(set) var passed = 0
    private var last: Duration?

    /// Call with the progress and the time; true when a tick should fire now. Holes passed
    /// while a tick was held back are not replayed.
    mutating func tick(progress: CGFloat, at now: Duration) -> Bool {
        let holes = TearMath.hiddenHoles(progress: progress)
        defer { passed = holes }
        guard holes > passed else { return false }
        if let last, now - last < TearMath.tickGap {
            return false
        }
        last = now
        return true
    }

    mutating func reset() {
        passed = 0
        last = nil
    }
}
