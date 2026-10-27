//
//  SpringHapticController.swift
//  Retrospect
//
//  Spring-resistance haptics for pull-up gestures: fires more frequently
//  and more intensely the further the user pulls.
//

import UIKit

/// Max pull distance used for progress (0...1). Tune this to match your gesture’s effective range.
let kSpringHapticMaxPullDistance: CGFloat = 300

/// Interval range: min (at full pull) and max (at start). Shorter = more frequent, more spring-like.
private let kSpringHapticIntervalMax: TimeInterval = 0.08 // 80ms at start
private let kSpringHapticIntervalMin: TimeInterval = 0.02 // 20ms at full pull

/// Exponent for progress curve. Higher = resistance ramps up more aggressively toward the end.
private let kSpringHapticProgressExponent: Double = 2.3

/// Intensity maps to [0.5, 1.0] so even small pulls feel noticeable.
private let kSpringHapticIntensityMin: Double = 0.5
private let kSpringHapticIntensityMax: Double = 1.0

final class SpringHapticController {

    static let shared = SpringHapticController()

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private var lastHapticTime: TimeInterval = 0

    private init() {}

    func prepare() {
        feedbackGenerator.prepare()
    }

    /// Call from gesture .changed with current pull distance and max distance.
    /// Rate-limited and intensity-curved to feel like pulling against a spring.
    func triggerSpringHaptic(pullDistance: CGFloat, maxDistance: CGFloat) {
        let now = CACurrentMediaTime()
        let progress = min(pullDistance / maxDistance, 1.0)

        let interval = kSpringHapticIntervalMax - (progress * (kSpringHapticIntervalMax - kSpringHapticIntervalMin))

        guard now - lastHapticTime >= interval else { return }
        lastHapticTime = now

        let raw = pow(progress, kSpringHapticProgressExponent)
        let intensity = kSpringHapticIntensityMin + raw * (kSpringHapticIntensityMax - kSpringHapticIntensityMin)
        if #available(iOS 13.0, *) {
            feedbackGenerator.impactOccurred(intensity: CGFloat(intensity))
        } else {
            feedbackGenerator.impactOccurred()
        }
    }

    /// Call on gesture end when user releases below threshold (spring snaps back).
    func triggerSnapBack() {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
        } else {
            feedbackGenerator.impactOccurred()
        }
    }

    /// Call when user releases above threshold (success — let go to enter app).
    func triggerSuccessHaptic() {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                let g = UIImpactFeedbackGenerator(style: .heavy)
                g.prepare()
                g.impactOccurred(intensity: 0.9)
            }
        } else {
            feedbackGenerator.impactOccurred()
        }
    }

    func reset() {
        lastHapticTime = 0
    }
}
