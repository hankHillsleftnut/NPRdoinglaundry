//
//  HapticManager.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Impact Feedback (Physical button presses, selections)
    
    func playLightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func playSoftImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func playMediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func playHeavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    @available(iOS 13.0, *)
    func playRigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback (System events, state changes)
    
    func playSuccessNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    func playWarningNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    func playErrorNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback (Picker changes, tab switches)
    
    func playSelectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Custom Feedback Patterns
    
    func playRecordingStart() {
        // Strong pattern for recording start
        playHeavyImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playMediumImpact()
        }
    }
    
    func playRecordingStop() {
        // Different pattern for recording stop
        playMediumImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playLightImpact()
        }
    }
    
    func playAudioPlayback() {
        // Gentle pattern for audio start
        playMediumImpact()
    }
    
    func playGenerationComplete() {
        // Celebration pattern for completion
        playSuccessNotification()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playLightImpact()
        }
    }
    
    func playNavigationTransition() {
        // Subtle feedback for navigation changes
        playLightImpact()
    }
    
    func playFocusChange() {
        // Very subtle feedback for input focus
        playSoftImpact()
    }

    /// Extremely gentle tick for text streaming in character-by-character.
    /// Uses a soft impact at low intensity so it feels like a whisper, not a tap.
    func playTextStreamTick() {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.35)
        } else {
            playSoftImpact()
        }
    }
    
    func playProgressMilestone() {
        // Feedback for progress indicators
        playSelectionChanged()
    }
    
    // MARK: - Progressive Hold Feedback
    
    func playProgressiveHaptic(intensity: Double) {
        // Progressive haptic intensity from 0.0 to 1.0
        // Maps to different haptic types based on intensity
        switch intensity {
        case 0.0..<0.2:
            playSoftImpact()
        case 0.2..<0.4:
            playLightImpact()
        case 0.4..<0.6:
            playMediumImpact()
        case 0.6..<0.8:
            playHeavyImpact()
        case 0.8...1.0:
            if #available(iOS 13.0, *) {
                playRigidImpact()
            } else {
                playHeavyImpact()
            }
        default:
            playLightImpact()
        }
    }
    
    /// Continuous, snappy pull feedback: intensity 0.0–1.0 maps to impact strength. Use for pull-to-activate.
    /// Call at small distance intervals as user pulls; intensity should increase with pull distance.
    func playPullProgressHaptic(intensity: Double) {
        let clamped = min(1.0, max(0.0, intensity))
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            // Map 0–1 to ~0.35–1.0 for snappier feel (avoid too-soft start)
            let systemIntensity = 0.35 + (clamped * 0.65)
            generator.impactOccurred(intensity: CGFloat(systemIntensity))
        } else {
            playProgressiveHaptic(intensity: clamped)
        }
    }
    
    func playHoldActivationSuccess() {
        // Special success pattern for hold activation
        playSuccessNotification()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playMediumImpact()
        }
    }
}
