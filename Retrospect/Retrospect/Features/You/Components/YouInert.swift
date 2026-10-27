//
//  YouInert.swift
//  V2.you: a control Paper draws whose destination isn't there yet is drawn exactly as Paper, inert (no
//  press feedback, no dimming), and "not available yet" to VoiceOver (DECISIONS 27 Oct consistency rule,
//  the "correct this part" pattern). One modifier and one string for every You screen.
//
import SwiftUI

enum YouCopy {
    /// What VoiceOver says for a drawn control with nothing behind it yet.
    static let notAvailableYet = "not available yet"
}

extension View {
    /// Drawn as Paper, inert, "not available yet" to VoiceOver; `false` leaves the view as it is.
    func youInert(_ inert: Bool = true) -> some View {
        allowsHitTesting(!inert)
            .accessibilityValue(inert ? YouCopy.notAvailableYet : "")
    }
}
