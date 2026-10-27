//
//  GoingInChip.swift
//  GR.ready, ON-10: "going in · what you just said" (Paper 26MU-0, inside c:getting-ready 26LV-0).
//  A raised pill, padded 4 by 12 with 8 between, tilted −2°: a "+" in accent.text mono, then the
//  words in the label face at --text-sm, text.primary. Its depth is Paper's (inner-top 1, outer 0.5,
//  contact 0 1 2, cast 0 8 18): the raised mark's recipe. It lands like the off-axis cards
//  (motion-system: rotates from 0° to its tilt on `settle`), and new words blur-replace the old.
//  Reduce Motion: it sits at its tilt from the start and the words cross-fade.
//
import SwiftUI

extension RTextStyle {
    /// The chip's "+" (Paper 26MW-0: --font-mono, --text-sm, leading snug).
    static let goingInMark = RTextStyle(
        family: .mono,
        size: RDimension.fontSizeSm,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: RTextStyle.body.leading,
        relativeTo: .caption
    )
}

struct GoingInChip: View {
    let text: String

    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Paper's tilt (rotate −2deg).
    static let tilt: Double = -2 // literal-ok: Paper 26MU-0 rotate

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RDimension.space2) {
            Text(verbatim: "+")
                .rText(.goingInMark)
                .foregroundStyle(RColor.accentText)
            Text(text)
                .rText(.metaLine)
                .foregroundStyle(RColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .id(text)
                .rBlurReplace()
        }
        .padding(.vertical, RDimension.space1)
        .padding(.horizontal, RDimension.space3)
        .rEmptyMark(RDimension.radiusControl)
        .rotationEffect(.degrees(landed || reduceMotion ? Self.tilt : 0))
        .onAppear {
            guard !landed else { return }
            withAnimation(reduceMotion ? nil : RMotion.settle) {
                landed = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("going in: \(text)")
        .accessibilityIdentifier("gettingReady.goingIn")
    }
}
