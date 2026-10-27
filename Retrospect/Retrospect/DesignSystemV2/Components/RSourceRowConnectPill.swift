//
//  RSourceRowConnectPill.swift
//  CN.connect: the source row's "+ connect" pill (Paper 21B9-0), kept in one place on purpose.
//  Founder, 26 Oct: Paper's pill is a flat soft cream pill with a very subtle outer shadow, not the
//  raised pill's light inner lip. It draws SH.composer's Paper look (#202: c:pill/raised rest D9Z-0,
//  pressed DA6-0, from the depth.boxShadow.pill.raised tokens); the old raised look stays as it is
//  everywhere else. No shadow values of its own.
//
import SwiftUI

struct RSourceRowConnectPill: View {
    /// The source it connects: VoiceOver hears "connect health", not a bare "connect".
    let source: String
    let action: () -> Void

    var body: some View {
        RPill(title: "connect", symbol: "plus", style: .raised, look: .paper, action: action)
            .accessibilityLabel("connect \(source)")
    }
}
