//
//  RMotionModifiers.swift
//  The shared motion vocabulary (design-system/principles/motion-system.md §6–§8).
//  Every value comes from RMotion / RNumber / RDimension / RHaptic. Each modifier
//  reads Reduce Motion itself and falls back to a 140ms cross-fade, so screens
//  never branch on it.
//
import SwiftUI

// MARK: - Press

/// Touch down shrinks in 80ms on the standard curve; release springs back on snappy.
/// Pass a haptic for lit or destructive actions (it fires once, on touch down).
struct RPressStyle: ButtonStyle {
    var scale: CGFloat = RNumber.motionScalePress
    var haptic: SensoryFeedback?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(
                configuration.isPressed
                    ? RMotion.standard(RNumber.motionDurationPressIn)
                    : RMotion.snappy,
                value: configuration.isPressed
            )
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in
                pressed ? haptic : nil
            }
    }
}

extension View {
    /// Applies the press response to a Button's label. Use 0.94 (`small: true`) for small controls.
    func rPress(small: Bool = false, haptic: SensoryFeedback? = nil) -> some View {
        buttonStyle(RPressStyle(scale: small ? RNumber.motionScalePressSmall : RNumber.motionScalePress, haptic: haptic))
    }
}

// MARK: - Appear (stagger)

private struct RAppear: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // Items past staggerMax arrive together with the last staggered one.
        let step = min(index, Int(RNumber.motionStaggerMax) - 1)
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : RDimension.motionAppearRise)
            .blur(radius: shown || reduceMotion ? 0 : RDimension.motionAppearBlurFrom)
            .onAppear {
                let animation = reduceMotion
                    ? RMotion.standard(RNumber.motionDurationFast)
                    : RMotion.standard(RNumber.motionDurationSlow).delay(Double(step) * RNumber.motionStagger)
                withAnimation(animation) { shown = true }
            }
    }
}

extension View {
    /// Rises 8pt and sharpens from 8pt of blur, top to bottom, 60ms apart.
    func rAppear(index: Int = 0) -> some View { modifier(RAppear(index: index)) }
}

// MARK: - Pop

private struct RPop<T: Equatable>: ViewModifier {
    let trigger: T
    let haptic: SensoryFeedback?
    @State private var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }
                scale = RNumber.motionScalePopoverFrom
                withAnimation(RMotion.pop) { scale = 1 }
            }
            .sensoryFeedback(trigger: trigger) { _, _ in haptic }
    }
}

extension View {
    /// A delight pop (~10% overshoot). Use rarely: knows-you-well, a goal met, the first episode ready.
    func rPop(trigger: some Equatable, haptic: SensoryFeedback? = RHaptic.confirm) -> some View {
        modifier(RPop(trigger: trigger, haptic: haptic))
    }
}

// MARK: - Shake

private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat
    func effectValue(size _: CGSize) -> ProjectionTransform {
        // Three oscillations that die out as the animation completes.
        let x = travel * sin(animatableData * .pi * 6) * (1 - animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

private struct RShake<T: Equatable>: ViewModifier {
    let trigger: T
    @State private var progress: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(travel: reduceMotion ? 0 : RDimension.motionShakeDistance, animatableData: progress))
            .onChange(of: trigger) { _, _ in
                progress = 0
                withAnimation(RMotion.standard(RNumber.motionDurationSlow * 2)) { progress = 1 }
            }
            .sensoryFeedback(RHaptic.warning, trigger: trigger)
    }
}

extension View {
    /// Error shake: 6pt, three oscillations, with the warning haptic.
    func rShake(trigger: some Equatable) -> some View { modifier(RShake(trigger: trigger)) }
}

// MARK: - Blur replace (changing text)

extension View {
    /// Changing text blurs out and in rather than double-printing. Animate the change with
    /// `withAnimation(RMotion.standard(RNumber.motionDurationSlow))`.
    func rBlurReplace() -> some View {
        contentTransition(.interpolate).transition(.blurReplace)
    }
}

// MARK: - Life (ambient float)

private struct RLastTouchKey: EnvironmentKey { static let defaultValue: Date = .distantPast }
extension EnvironmentValues {
    /// When the person last touched the screen. Set once at the root with `.rLifeHost()`.
    var rLastTouch: Date {
        get { self[RLastTouchKey.self] }
        set { self[RLastTouchKey.self] = newValue }
    }
}

private struct RLifeHost: ViewModifier {
    @State private var lastTouch: Date = .distantPast
    func body(content: Content) -> some View {
        content
            .environment(\.rLastTouch, lastTouch)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in lastTouch = Date() })
    }
}

private struct RFloat: ViewModifier {
    let phase: Double
    @State private var start = Date()
    /// Eases to 0 while the person is touching, back to 1 after motion.life.resumeAfter.
    @State private var strength: CGFloat = 1
    @Environment(\.rLastTouch) private var lastTouch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        if reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled || scenePhase != .active {
            content
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(start) / RNumber.motionLifeFloatPeriod
                content.offset(y: RDimension.motionLifeFloatAmplitude * strength * sin((t + phase) * 2 * .pi))
            }
            .onChange(of: lastTouch) { _, _ in
                withAnimation(RMotion.standard(RNumber.motionDurationSlow)) { strength = 0 }
                Task {
                    try? await Task.sleep(for: .seconds(RNumber.motionLifeResumeAfter))
                    if Date().timeIntervalSince(lastTouch) >= RNumber.motionLifeResumeAfter {
                        withAnimation(RMotion.gentle) { strength = 1 }
                    }
                }
            }
        }
    }
}

extension View {
    /// Ambient drift (§7): 2pt on a 5s sine. One per screen at most. Give neighbours different phases.
    /// Stills while the person touches the screen (needs `.rLifeHost()` at the root).
    func rFloat(phase: Double = 0) -> some View { modifier(RFloat(phase: phase)) }

    /// Put once at the app's root so ambient motion knows when the person is touching.
    func rLifeHost() -> some View { modifier(RLifeHost()) }
}

// MARK: - Scroll lag (tiles)

extension View {
    /// Tiles lag a little behind the scroll and settle (founder, 20 Oct): up to 6pt and 1.5°.
    func rScrollLag() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .offset(x: phase.value * RDimension.motionScrollLagMaxOffset)
                .rotationEffect(.degrees(phase.value * RNumber.motionScrollLagMaxTilt))
        }
    }
}
