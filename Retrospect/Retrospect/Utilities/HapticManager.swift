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
    
    func playHoldActivationSuccess() {
        // Special success pattern for hold activation
        playSuccessNotification()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playMediumImpact()
        }
    }
}
