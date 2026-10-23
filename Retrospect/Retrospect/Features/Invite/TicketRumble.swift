//
//  TicketRumble.swift
//  PI2.1: the soft rumble in the hand while the ticket prints (a continuous Core Haptics event,
//  intensity 0.25, sharpness 0.1) that stops when the print lands. Silent on hardware without
//  haptics (the simulator) and never throws: a haptic that can't play is simply not felt.
//
import CoreHaptics
import Foundation

@MainActor
final class TicketRumble {
    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?

    /// The print takes about 2.5 s from first line to landing, with the rumble's own decay.
    private static let duration: TimeInterval = 2.5

    func start() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                ],
                relativeTime: 0, duration: Self.duration
            )
            let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            self.engine = engine
            self.player = player
        } catch {
            stop()
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        engine?.stop()
        player = nil
        engine = nil
    }
}
