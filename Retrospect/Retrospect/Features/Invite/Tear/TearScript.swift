//
//  TearScript.swift
//  TEAR.motion: one scripted finger, so the lab's recordings of the current and the physical tear
//  line up frame for frame, and the tests tear the way the recordings do. Debug only.
//
#if DEBUG
import CoreGraphics
import Foundation

/// A person tearing at an easy pace: touch the notch, wait a beat, drag to 74% on an ease-in-out
/// that still has speed at the lift, the finger a little below the line. Times from touch-down.
enum TearScript {
    static let lead = 0.6 // literal-ok: still frames before the touch, for the recording
    static let hold = 0.15 // literal-ok: the beat on the notch
    static let drag = 0.9 // literal-ok: the drag itself
    static let reach = 0.74 // literal-ok: past the 62% threshold
    /// The sample redeem answers 0.3 s after the commit (SampleInviteSource).
    static let redeem = 0.3 // literal-ok: sample source timing

    /// Where the finger is: along the line, below it, and whether it is down.
    struct Touch {
        var x: CGFloat
        var dy: CGFloat
        var down: Bool
    }

    static func finger(at t: Double, width: CGFloat) -> Touch {
        guard t >= 0 else { return Touch(x: 0, dy: 0, down: false) }
        guard t >= hold else { return Touch(x: 0, dy: 0, down: true) }
        let s = min((t - hold) / drag, 1)
        let eased = 0.7 * s * s * (3 - 2 * s) + 0.3 * s // literal-ok: a human drag, not a ramp
        return Touch(x: width * CGFloat(reach * eased), dy: CGFloat(4 + 10 * s), down: s < 1) // literal-ok: finger 4…14pt below the line
    }

    static var releaseAt: Double {
        hold + drag
    }

    static func releaseVelocity(width: CGFloat) -> CGFloat {
        width * CGFloat(reach * 0.3 / drag) // literal-ok: the linear share of the ease is the speed at the lift
    }
}
#endif
