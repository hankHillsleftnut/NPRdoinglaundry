//
//  ExposureFont.swift
//  Retrospect
//
//  Helper for the 205TF "Exposure" trial typeface. The family ships as static
//  instances along an "exposure" axis from -100 (lightest) to +100 (heaviest)
//  in steps of 10. Each instance is its own font family, so we address them by
//  their embedded PostScript name (e.g. "ExposureTrial-+50").
//
//  Usage:
//     Text("Hello").font(.exposure(50, size: 32))            // heavier
//     Text("Hello").font(.exposure(-30, size: 17, italic: true))
//

import SwiftUI

enum ExposureFont {
    /// Valid axis stops: -100, -90, … 0 … +90, +100 (step 10).
    static let axisStops: [Int] = Array(stride(from: -100, through: 100, by: 10))

    /// Snap an arbitrary value to the nearest available 10-step stop.
    static func snap(_ value: Int) -> Int {
        let clamped = max(-100, min(100, value))
        return Int((Double(clamped) / 10.0).rounded()) * 10
    }

    /// PostScript name for a given axis stop. Matches the names embedded in the
    /// .otf files: "ExposureTrial-0", "ExposureTrial-+50", "ExposureTrial--50".
    static func postScriptName(axis: Int, italic: Bool) -> String {
        let base = italic ? "ExposureItalicTrial" : "ExposureTrial"
        let snapped = snap(axis)
        let suffix: String
        if snapped == 0 { suffix = "0" }
        else if snapped > 0 { suffix = "+\(snapped)" }
        else { suffix = "\(snapped)" } // already has leading "-"
        return "\(base)-\(suffix)"
    }
}

extension Font {
    /// Exposure typeface at a given axis (-100…+100, snapped to nearest 10).
    /// Negative = lighter/thinner, positive = heavier/bolder.
    static func exposure(_ axis: Int = 0, size: CGFloat, italic: Bool = false) -> Font {
        .custom(ExposureFont.postScriptName(axis: axis, italic: italic), size: size)
    }
}
