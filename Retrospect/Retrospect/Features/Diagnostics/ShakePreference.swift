//
//  ShakePreference.swift
//  DG.6: the shake trigger and its switch (docs/team/flows/diagnostics.md, DQ1). On in
//  TestFlight and debug builds, off in App Store builds, and the person can change it in
//  settings. The detector is pure (a stream of accelerometer magnitudes in, "shaken" out) so it
//  is tested without a phone; `ShakeMonitor` feeds it from the accelerometer, which needs no
//  permission, and only while the switch is on and the app is in front.
//
import CoreMotion
import Foundation
import SwiftUI

enum ShakePreference {
    /// The `UserDefaults` key the switch is stored under.
    static let key = "diagnostics.shakeToSendReport"

    /// DQ1's lean: on for testers, off for everyone else. A TestFlight build's receipt is named
    /// `sandboxReceipt`; a debug build has none.
    static func defaultValue(receiptName: String?, isDebug: Bool) -> Bool {
        isDebug || receiptName == "sandboxReceipt"
    }

    static var defaultValue: Bool {
        #if DEBUG
        defaultValue(receiptName: nil, isDebug: true)
        #else
        defaultValue(receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent, isDebug: false)
        #endif
    }
}

/// Two hard knocks inside a short window is a shake; one bump in a bag or a table is not.
struct ShakeDetector {
    /// Total acceleration, in g, above which a sample counts as a knock (rest is 1).
    var threshold = 2.2
    /// Two knocks must land within this long.
    var window: TimeInterval = 0.8
    /// Knocks closer together than this are one knock.
    var debounce: TimeInterval = 0.12
    /// After a shake, nothing counts for this long.
    var cooldown: TimeInterval = 2

    private var lastKnock: TimeInterval?
    private var previousKnock: TimeInterval?
    private var quietUntil: TimeInterval = -.infinity

    /// Feeds one sample (`magnitude` in g at `time` in seconds); true when it completes a shake.
    mutating func feed(magnitude: Double, at time: TimeInterval) -> Bool {
        guard time >= quietUntil, magnitude >= threshold else { return false }
        if let lastKnock, time - lastKnock < debounce {
            return false
        }
        previousKnock = lastKnock
        lastKnock = time
        guard let previousKnock, time - previousKnock <= window else { return false }
        quietUntil = time + cooldown
        self.previousKnock = nil
        lastKnock = nil
        return true
    }
}

/// Listens to the accelerometer while the switch is on and the app is in front.
@MainActor
final class ShakeMonitor {
    private let manager = CMMotionManager()
    private var detector = ShakeDetector()
    private var onShake: (() -> Void)?

    func start(_ handler: @escaping () -> Void) {
        guard manager.isAccelerometerAvailable, !manager.isAccelerometerActive else { return }
        onShake = handler
        detector = ShakeDetector()
        manager.accelerometerUpdateInterval = 1.0 / 30 // literal-ok: sampling rate, not a layout value
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let pull = data.acceleration
            let magnitude = (pull.x * pull.x + pull.y * pull.y + pull.z * pull.z).squareRoot()
            if detector.feed(magnitude: magnitude, at: data.timestamp) {
                onShake?()
            }
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        onShake = nil
    }

    deinit {
        manager.stopAccelerometerUpdates()
    }
}
