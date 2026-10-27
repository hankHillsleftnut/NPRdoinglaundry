//
//  RotateModifier.swift
//  Retrospect fina (SwiftUI)
//
//  Created by Shaurya Narang on 5/13/25.
//

import SwiftUI

/// Custom modifier to handle the rotation animation
struct RotateModifier: AnimatableModifier {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(Angle(degrees: phase))
    }
}
