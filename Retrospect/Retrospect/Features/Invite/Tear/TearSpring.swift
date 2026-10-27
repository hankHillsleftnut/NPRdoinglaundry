//
//  TearSpring.swift
//  TEAR.motion: the small pieces of physics the tear is made of, pure and exact (closed form, so a
//  frame rate never changes a result): the design system's springs, gravity with air drag, and the
//  curve the torn flap bends along (the same curve TearBend.metal draws).
//
import CoreGraphics
import Foundation

// MARK: - Springs

/// A damped spring named by the design system's two numbers (`motion.spring.*`), solved exactly.
struct TearSpring: Equatable {
    let response: Double
    let damping: Double

    /// No tear spring is damped below `motion.tear.dampingFloor` (pop's 0.6): asking for less gets the floor.
    init(response: Double, damping: Double) {
        self.response = response
        self.damping = max(damping, RNumber.motionTearDampingFloor)
    }

    /// `motion.spring.snappy`.
    static let snappyPair = TearSpring(response: RNumber.motionSpringSnappyResponse, damping: RNumber.motionSpringSnappyDamping)
    /// `motion.spring.settle`.
    static let settlePair = TearSpring(response: RNumber.motionSpringSettleResponse, damping: RNumber.motionSpringSettleDamping)
    /// `motion.spring.pop`: the lowest damping the system allows.
    static let popPair = TearSpring(response: RNumber.motionSpringPopResponse, damping: RNumber.motionSpringPopDamping)

    /// Displacement from the target and velocity at `t`, starting at displacement `x0` with velocity `v0`.
    func state(from x0: Double, velocity v0: Double, at t: Double) -> (x: Double, v: Double) {
        let omega = 2 * Double.pi / response
        let zeta = min(damping, 0.999) // literal-ok: the underdamped solution's edge (critical damping is its limit)
        let omegaD = omega * (1 - zeta * zeta).squareRoot()
        let decay = exp(-zeta * omega * t)
        let cosine = cos(omegaD * t)
        let sine = sin(omegaD * t)
        let x = decay * (x0 * cosine + (v0 + zeta * omega * x0) / omegaD * sine)
        let v = decay * (v0 * cosine - (zeta * omega * v0 + omega * omega * x0) / omegaD * sine)
        return (x, v)
    }

    /// One exact step toward a target that may move between steps (finger-driven values).
    func step(_ value: inout Double, _ velocity: inout Double, toward target: Double, dt: Double) {
        let next = state(from: value - target, velocity: velocity, at: dt)
        value = target + next.x
        velocity = next.v
    }
}

// MARK: - Free fall

/// Gravity with linear air drag, in closed form.
struct TearFall: Equatable {
    var gravity: Double
    var drag: Double

    func state(velocity v0: Double, at t: Double) -> (y: Double, v: Double) {
        let terminal = gravity / drag
        let decay = exp(-drag * t)
        return (terminal * t + (v0 - terminal) * (1 - decay) / drag, terminal + (v0 - terminal) * decay)
    }

    /// When the fall has covered `distance` (bisection; the fall is monotonic for v0 >= 0).
    func time(toCover distance: Double, velocity v0: Double) -> Double {
        guard distance > 0 else { return 0 }
        var low = 0.0
        var high = 2.0
        for _ in 0 ..< 50 {
            let mid = (low + high) / 2
            if state(velocity: v0, at: mid).y < distance {
                low = mid
            } else {
                high = mid
            }
        }
        return (low + high) / 2
    }
}

// MARK: - The peel's curve

/// The torn flap as one bending sheet (founder, 26 Oct: "a smooth curve along the stub, like a ticket
/// peeling away", never a rigid plate). Right of `front` the paper is still joined and flat. Left of it
/// the flap's tangent turns continuously, as a cantilever hanging under its own weight: the turn at `s`
/// points from the front is `angle · (1 - (1 - s/length)^exponent)`, so the curve is tightest at the peel,
/// eases out along the flap and reaches `angle` at the tip. A point `h` below the perforation stays `h`
/// along the paper's normal (the sheet bends; it never stretches or shears). TearBend.metal draws exactly
/// this (the same four-point quadrature).
struct TearCurve: Equatable {
    /// Where the paper is still joined (the tear front), in the stub's own points.
    var front: CGFloat
    /// The perforation's height in the stub's points.
    var pivotY: CGFloat
    /// The tip's tangent, degrees; negative hangs the left end down (as `rotationEffect`).
    var angle: Double
    /// The flap's length left of the front (the whole torn length).
    var length: CGFloat
    var exponent = RNumber.motionTearCurveExponent

    /// Gauss–Legendre, four points: exact for this smooth integrand to far below a pixel.
    private static let nodes = [-0.861_136_311_6, -0.339_981_043_6, 0.339_981_043_6, 0.861_136_311_6] // literal-ok: quadrature
    private static let weights = [0.347_854_845_1, 0.652_145_154_9, 0.652_145_154_9, 0.347_854_845_1] // literal-ok: quadrature

    /// How far the tangent has turned down, radians, `s` points left of the front.
    func turn(at s: CGFloat) -> Double {
        guard s > 0, length > 0 else { return 0 }
        let share = min(Double(s / length), 1)
        return -angle * .pi / 180 * (1 - pow(1 - share, exponent))
    }

    /// Where the perforation line, `s` points left of the front, has moved to (relative to the front).
    func edge(at s: CGFloat) -> CGSize {
        guard s > 0 else { return CGSize(width: -s, height: 0) }
        let bent = Double(min(s, length))
        var x = 0.0
        var y = 0.0
        for (node, weight) in zip(Self.nodes, Self.weights) {
            let sigma = bent / 2 * (node + 1)
            let turn = turn(at: CGFloat(sigma))
            x -= weight * cos(turn)
            y += weight * sin(turn)
        }
        x *= bent / 2
        y *= bent / 2
        // past the tip (never on the paper itself) the sheet runs straight on
        let rest = Double(s) - bent
        let tip = turn(at: length)
        return CGSize(width: x - rest * cos(tip), height: y + rest * sin(tip))
    }

    /// Where a point of the flat stub is drawn.
    func place(_ point: CGPoint) -> CGPoint {
        let s = front - point.x
        let h = Double(point.y - pivotY)
        let along = edge(at: s)
        let turn = turn(at: s)
        return CGPoint(x: front + along.width + CGFloat(h * sin(turn)), y: pivotY + along.height + CGFloat(h * cos(turn)))
    }

    /// The flap's tangent direction, degrees below the horizontal, at the tip.
    var tipAngle: Double {
        turn(at: length) * 180 / .pi
    }

    /// The angle of the straight line from the front to the point `s` left of it, in the
    /// `rotationEffect` sense (negative: hanging down): the rigid turn that would put that point where
    /// the curve puts it.
    func chordAngle(at s: CGFloat) -> Double {
        let point = edge(at: s)
        return -atan2(Double(point.height), Double(-point.width)) * 180 / .pi
    }
}

/// Rotates a vector by `degrees` (positive is clockwise on screen, as SwiftUI's rotationEffect).
func tearRotate(_ v: CGSize, _ degrees: Double) -> CGSize {
    let r = degrees * .pi / 180
    return CGSize(width: v.width * cos(r) - v.height * sin(r), height: v.width * sin(r) + v.height * cos(r))
}
