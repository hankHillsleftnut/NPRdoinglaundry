//
//  RMotionExtras.swift
//  Motion tokens that don't fit the generator's spring and cubic-bezier shapes
//  (design-system/principles/motion-system.md §2).
//
import SwiftUI

extension RMotion {
    /// motion.curve.reveal: long and calm, for the first-insight moment and the splash.
    static let reveal: Animation = .smooth(duration: RNumber.motionDurationReveal, extraBounce: 0.02)

    /// motion.duration.spin, repeating: continuous rotation follows real time, the one
    /// place a linear ramp is right (motion-system §1). Spinners only.
    static let spin: Animation = .linear(duration: RNumber.motionDurationSpin).repeatForever(autoreverses: false)
}
