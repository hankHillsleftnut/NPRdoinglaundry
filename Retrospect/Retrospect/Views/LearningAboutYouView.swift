//
//  LearningAboutYouView.swift
//  Retrospect
//
//  The pre-first-podcast "learning about you" ritual. Inverted fluid-dots
//  (cream background, dark ink metaballs): press and hold — dots gather and
//  follow your finger, merging into the blob as you hold — then drag to the
//  other side to commit, then an "understanding your touch" settle. Core
//  Haptics ramp throughout. Generation runs in the background; this masks it.
//
//  NOTE: haptics only fire on a physical device, not the Simulator.
//

import CoreHaptics
import MetalKit
import SwiftUI

// MARK: - Metal renderer (drives learningTouchFragment)

struct LearningTouchRenderer: UIViewRepresentable {
    var touch: SIMD2<Float>
    var holdProgress: Float
    var touchActive: Float
    var release: Float
    var dissolve: Float = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = context.coordinator.device
        v.delegate = context.coordinator
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = true
        v.isOpaque = true
        v.clearColor = MTLClearColor(red: 0.929, green: 0.918, blue: 0.886, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        return v
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        let c = context.coordinator
        c.touch = touch
        c.holdProgress = holdProgress
        c.touchActive = touchActive
        c.release = release
        c.dissolve = dissolve
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        let device = MTLCreateSystemDefaultDevice()
        private let queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private let start = CACurrentMediaTime()

        var touch = SIMD2<Float>(0, 0)
        var holdProgress: Float = 0
        var touchActive: Float = 0
        var release: Float = 0
        var dissolve: Float = 0

        struct U {
            var iResolution: SIMD2<Float>
            var touch: SIMD2<Float>
            var iTime: Float
            var holdProgress: Float
            var touchActive: Float
            var release: Float
            var dissolve: Float
        }

        override init() {
            queue = device?.makeCommandQueue()
            super.init()
            build()
        }

        private func build() {
            guard let device,
                  let lib = device.makeDefaultLibrary(),
                  let vf = lib.makeFunction(name: "fluidDotsVertex"),
                  let ff = lib.makeFunction(name: "learningTouchFragment") else { return }
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = vf
            d.fragmentFunction = ff
            d.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline = try? device.makeRenderPipelineState(descriptor: d)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let pipeline, let queue,
                  let rpd = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let cb = queue.makeCommandBuffer(),
                  let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
            let s = view.drawableSize
            var u = U(
                iResolution: SIMD2<Float>(Float(s.width), Float(s.height)),
                touch: touch,
                iTime: Float(CACurrentMediaTime() - start),
                holdProgress: holdProgress,
                touchActive: touchActive,
                release: release,
                dissolve: dissolve
            )
            enc.setRenderPipelineState(pipeline)
            enc.setFragmentBytes(&u, length: MemoryLayout<U>.stride, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
            cb.present(drawable)
            cb.commit()
        }
    }
}

// MARK: - Haptics

final class LearningHaptics {
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var supported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func prepare() {
        guard supported else { return }
        do {
            let e = try CHHapticEngine()
            e.resetHandler = { [weak e] in try? e?.start() }
            try e.start()
            engine = e
        } catch { engine = nil }
    }

    func startContinuous() {
        guard supported, let engine else { return }
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
        ], relativeTime: 0, duration: 120)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: 0)
        } catch {}
    }

    func updateContinuous(intensity: Float, sharpness: Float) {
        guard supported, let continuousPlayer else { return }
        let ip = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: max(0, min(1, intensity)), relativeTime: 0)
        let sp = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: max(0, min(1, sharpness)), relativeTime: 0)
        try? continuousPlayer.sendParameters([ip, sp], atTime: 0)
    }

    func transient(intensity: Float, sharpness: Float) {
        guard supported, let engine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {}
    }

    func stop() {
        try? continuousPlayer?.stop(atTime: 0)
        continuousPlayer = nil
        engine?.stop(completionHandler: nil)
        engine = nil
    }
}

// MARK: - The ritual

struct LearningAboutYouView: View {
    /// Gates completion: the ritual won't finish until the podcast is ready.
    var podcastReady: Bool = true
    var onComplete: () -> Void = {}

    private enum Phase { case building, sustaining, releasing, formed, dissolving, done }

    @State private var phase: Phase = .building
    @State private var hold: Double = 0
    @State private var release: Double = 0
    @State private var dissolve: Double = 0
    @State private var sustainTime: Double = 0
    @State private var formedTime: Double = 0
    @State private var loadProgress: Double = 0
    @State private var calloutIndex = 0
    @State private var calloutTime: Double = 0
    @State private var lastJoinTick = 0

    private let haptics = LearningHaptics()
    private let BUILD = 5.0 // seconds for the vacuum to fill (faster)
    private let MIN_SUSTAIN = 2.0 // minimum full-intensity hold before it resolves
    private let RELEASE = 3.5 // the grand collapse
    private let FORMED_HOLD = 1.1 // sit, move and warp before launching up
    private let DISSOLVE = 0.55 // the orb shoots up off the top (fast)
    private let calloutInterval = 3.0

    /// Placeholder callouts — swap for the real "what I noticed about you" source.
    private let callouts = [
        "Learning about you.",
        "You carry more than you let on.",
        "You move fast, and rarely stop to notice.",
        "There's a pattern in what you keep returning to.",
        "You're harder on yourself than the evidence warrants.",
    ]

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let cream = Color(red: 0.929, green: 0.918, blue: 0.886)
    private let inkText = Color(red: 0.1, green: 0.09, blue: 0.08)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            LearningTouchRenderer(
                touch: SIMD2<Float>(0, 0),
                holdProgress: Float(hold),
                touchActive: 0,
                release: Float(release),
                dissolve: Float(dissolve)
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                Text(caption)
                    .font(.custom("HedvigLettersSerif-24ptRegular", size: 30))
                    .foregroundColor(inkText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .animation(.easeInOut(duration: 0.45), value: caption)

                // tiny monospace progress bar + percentage
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(inkText.opacity(0.12)).frame(width: 120, height: 3)
                        Capsule().fill(inkText.opacity(0.85)).frame(width: 120 * loadProgress, height: 3)
                    }
                    Text("\(Int(loadProgress * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(inkText.opacity(0.55))
                        .frame(width: 40, alignment: .leading)
                }
                .padding(.bottom, 88)
            }
            .opacity(1.0 - dissolve)
        }
        .onAppear { haptics.prepare(); haptics.startContinuous() }
        .onReceive(timer) { _ in tick() }
    }

    private var caption: String {
        switch phase {
        case .building, .sustaining:
            return callouts[calloutIndex % callouts.count]
        case .releasing, .formed, .dissolving, .done:
            return "Understanding you."
        }
    }

    // Auto-plays: the vacuum fills, holds at full while the podcast generates,
    // then a grand collapse dissolves into the podcast. No touch.
    private func tick() {
        let dt = 1.0 / 60.0

        // Cycle the callouts while loading.
        if phase == .building || phase == .sustaining {
            calloutTime += dt
            if calloutTime >= calloutInterval {
                calloutTime = 0
                calloutIndex += 1
            }
        }

        switch phase {
        case .building:
            hold = min(0.9, hold + dt / BUILD)
            loadProgress += (0.95 - loadProgress) * dt * 0.16
            let joinTick = Int(hold * 7)
            if joinTick > lastJoinTick {
                lastJoinTick = joinTick
                haptics.transient(intensity: 0.4, sharpness: 0.55) // a droplet pooled in
            }
            haptics.updateContinuous(
                intensity: Float(0.12 + 0.70 * hold),
                sharpness: Float(0.2 + 0.4 * hold)
            )
            if hold >= 0.9 {
                phase = .sustaining
            }
        case .sustaining:
            // Keep growing — asymptotic creep, never stalls — while the podcast generates.
            hold += (0.99 - hold) * dt * 0.35
            loadProgress += (0.95 - loadProgress) * dt * 0.10 // indeterminate creep toward 95%
            sustainTime += dt
            haptics.updateContinuous(intensity: 0.82, sharpness: 0.6)
            if sustainTime >= MIN_SUSTAIN, podcastReady {
                phase = .releasing
            }
        case .releasing:
            hold = min(1.0, hold + dt * 0.5) // finish filling smoothly
            release = min(1.0, release + dt / RELEASE)
            loadProgress = min(1.0, loadProgress + dt * 0.7) // complete to 100%
            haptics.updateContinuous(intensity: Float(0.5 * (1.0 - release)), sharpness: 0.3)
            if release >= 1.0 {
                phase = .formed
            }
        case .formed:
            // The mass sits, moving and warping, before it launches.
            loadProgress = 1.0
            formedTime += dt
            if formedTime >= FORMED_HOLD {
                phase = .dissolving
                haptics.transient(intensity: 1.0, sharpness: 0.4) // grand beat as it launches
            }
        case .dissolving:
            dissolve = min(1.0, dissolve + dt / DISSOLVE)
            if dissolve >= 1.0 {
                phase = .done
                haptics.stop()
                onComplete()
            }
        case .done:
            break
        }
    }
}

#if DEBUG
/// Verification host for the `-LearningTouch` launch flag.
struct LearningTouchDebugHost: View {
    @State private var done = false
    @State private var key = 0
    var body: some View {
        ZStack {
            LearningAboutYouView(podcastReady: true, onComplete: { done = true })
                .id(key)
            if done {
                VStack(spacing: 16) {
                    Text("✓ complete").font(.system(size: 22, weight: .semibold))
                    Button("Replay") { done = false; key += 1 }
                }
                .padding(24)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

/// Auto-driven visual demo (no touch) for verifying the shader choreography in
/// the Simulator. `-LearningTouchAuto`.
struct LearningTouchAutoDemo: View {
    @State private var hold: Double = 0
    @State private var release: Double = 0
    @State private var dissolve: Double = 0
    @State private var phase = 0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            Color(red: 0.929, green: 0.918, blue: 0.886).ignoresSafeArea()
            LearningTouchRenderer(touch: SIMD2<Float>(0, 0), holdProgress: Float(hold), touchActive: 0, release: Float(release), dissolve: Float(dissolve))
                .ignoresSafeArea()
            VStack {
                Spacer()
                Text(String(format: "auto · hold %.2f · release %.2f · dissolve %.2f", hold, release, dissolve))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.bottom, 80)
            }
        }
        .onReceive(timer) { _ in
            let dt = 1.0 / 60.0
            switch phase {
            case 0: hold = min(1, hold + dt / 4); if hold >= 1 {
                    phase = 1
                }
            case 1: release = min(1, release + dt / 5); if release >= 1 {
                    phase = 2
                }
            default:
                dissolve = min(1, dissolve + dt / 1.2)
                if dissolve >= 1 {
                    phase = 0; hold = 0; release = 0; dissolve = 0
                }
            }
        }
    }
}
#endif
