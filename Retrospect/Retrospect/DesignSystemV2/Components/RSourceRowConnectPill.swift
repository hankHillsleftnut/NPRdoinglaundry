//
//  RSourceRowConnectPill.swift
//  CN.connect: the source row's "+ connect" pill (Paper 21B9-0), kept in one place on purpose.
//  Founder, 26 Oct: Paper's pill is a flat soft cream pill with a very subtle outer shadow; today's
//  raised pill has a light inner lip. The Paper-exact pill and its shadow tokens come from SH.composer
//  (the old raised pill is kept as it is); when they land, the one line in `body` changes to that
//  pill. Until then this is today's raised pill, with no shadow values of its own.
//
import SwiftUI

struct RSourceRowConnectPill: View {
    /// The source it connects: VoiceOver hears "connect health", not a bare "connect".
    let source: String
    let action: () -> Void

    var body: some View {
        // SWAP: the Paper-exact pill (SH.composer) goes here, in this one line
        RPill(title: "connect", symbol: "plus", style: .raised, action: action)
            .accessibilityLabel("connect \(source)")
    }
}
