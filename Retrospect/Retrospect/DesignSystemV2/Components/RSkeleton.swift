//
//  RSkeleton.swift
//  M14 C39.1: loading (design-system/components/loading-and-empty.md, reference §C39; Paper
//  legacy c5 "brief card / making" 20M-0). Bars in the shape of the content: surface.skeleton,
//  size.skeleton.bar 18 tall on a 27 line (size.skeleton.gap 9), radius.small corners, a shine
//  sweeping left to right every motion.duration.shimmer on curve.move. `RLoading` decides when
//  to show it: nothing for the first motion.duration.skeletonDelay (a quick load never flashes
//  one), the skeleton after that, "still working" under it after motion.duration.stillWorking,
//  and the content cross-fading in (140) when it arrives. Every wait is on an injected clock.
//
import Observation
import SwiftUI

// MARK: - Bars

struct RSkeleton: View {
    /// One bar per line of the content it stands for: a width in points, or nil for the full width.
    let bars: [CGFloat?]

    @ScaledMetric(relativeTo: .body) private var barHeight = RDimension.sizeSkeletonBar
    @ScaledMetric(relativeTo: .body) private var gap = RDimension.sizeSkeletonGap
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        shapes(RColor.surfaceSkeleton)
            .overlay {
                if reduceMotion {
                    // Reduce Motion: no shine; the bars breathe instead
                    shapes(contrast == .increased ? RColor.surfaceSkeletonContrast : RColor.surfaceSkeleton)
                        .opacity(phase == 0 ? 1 : RNumber.opacitySkeletonPulseFloor)
                } else {
                    shine.mask { shapes(RColor.surfaceSkeleton) }
                }
            }
            .padding(.vertical, lineMargin)
            .onAppear {
                let animation = RMotion.move(RNumber.motionDurationShimmer).repeatForever(autoreverses: reduceMotion)
                withAnimation(animation) { phase = 1 }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("loading")
    }

    /// Half a gap above the first bar and below the last, so each bar sits centred on its line.
    private var lineMargin: CGFloat {
        gap / 2
    }

    private func shapes(_ fill: Color) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
                RShape.rect(RDimension.radiusSmall)
                    .fill(contrast == .increased ? RColor.surfaceSkeletonContrast : fill)
                    .frame(maxWidth: width ?? .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// surface.skeletonShine peaking in the middle and fading to nothing at both edges (so it never
    /// draws a seam on the bars), one skeleton wide, travelling from fully left of the bars to
    /// fully right of them.
    private var shine: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [RColor.surfaceSkeletonShine.opacity(0), RColor.surfaceSkeletonShine, RColor.surfaceSkeletonShine.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width)
            .offset(x: (phase * 2 - 1) * proxy.size.width)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - When it shows

/// What a loading area shows at a moment, from how long it has been loading.
enum RLoadingPhase: Equatable {
    /// Under the delay: nothing new (whatever was there, or the blank page).
    case waiting
    case skeleton
    /// Long enough to say so: the skeleton with "still working" under it.
    case stillWorking

    init(after elapsed: Duration) {
        if elapsed < .seconds(RNumber.motionDurationSkeletonDelay) {
            self = .waiting
        } else if elapsed < .seconds(RNumber.motionDurationStillWorking) {
            self = .skeleton
        } else {
            self = .stillWorking
        }
    }
}

/// Moves a loading area through its phases on the clock it's given; cancelling the task stops it.
@MainActor
@Observable
final class RLoadingTimer {
    private(set) var phase: RLoadingPhase = .waiting

    /// Both deadlines are measured from the load's start, so a late wake never pushes
    /// "still working" past motion.duration.stillWorking.
    func run(on clock: some Clock<Duration>) async {
        phase = .waiting
        let start = clock.now
        do {
            try await clock.sleep(until: start.advanced(by: .seconds(RNumber.motionDurationSkeletonDelay)), tolerance: nil)
            phase = .skeleton
            try await clock.sleep(until: start.advanced(by: .seconds(RNumber.motionDurationStillWorking)), tolerance: nil)
            phase = .stillWorking
        } catch {
            return
        }
    }

    func reset() {
        phase = .waiting
    }
}

extension EnvironmentValues {
    /// The clock loading areas wait on: the real one in the app, a test clock in tests.
    @Entry var rLoadingClock: any Clock<Duration> = ContinuousClock()
}

/// Shows `content` once loaded; while loading, nothing for the first 400ms, then `skeleton`,
/// then "still working" under it after 8s. The content cross-fades in over 140ms.
struct RLoading<Content: View, Skeleton: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let skeleton: () -> Skeleton

    @State private var timer = RLoadingTimer()
    @Environment(\.rLoadingClock) private var clock

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isLoading {
                if timer.phase != .waiting {
                    VStack(alignment: .leading, spacing: RDimension.space2) {
                        skeleton()
                        if timer.phase == .stillWorking {
                            Text("still working")
                                .rText(.metaLine)
                                .foregroundStyle(RColor.textLabel)
                                .rBlurReplace()
                        }
                    }
                    .transition(.opacity.animation(RMotion.standard(RNumber.motionDurationFast)))
                }
            } else {
                content()
                    .transition(.opacity.animation(RMotion.standard(RNumber.motionDurationFast)))
            }
        }
        .task(id: isLoading) {
            guard isLoading else {
                timer.reset()
                return
            }
            await timer.run(on: clock)
        }
    }
}

#if DEBUG
/// Lab page "skeleton": the brief card's "being made" bars (20M-0), and a load that takes
/// 0.3s, 2s and 10s. `-DesignLabAutoplay` runs the three loads in turn, for recordings.
struct RSkeletonGallery: View {
    @State private var loading = false
    @State private var label = "not loading"
    /// The load in flight; a new one cancels it, so an old load never ends the new one.
    @State private var current: Task<Void, Never>?
    /// Each load gets a fresh identity, so RLoading starts its timer over.
    @State private var loadCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                caption("your brief is being made (20M-0)")
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    Text("your brief is being made").rText(.metaLine).foregroundStyle(RColor.textLabel)
                    RSkeleton(bars: [240, 150])
                }
                .padding(RDimension.space4)
                .rRaised()
                caption("a load: \(label)")
                RLoading(isLoading: loading) {
                    Text("you've slept under seven hours four nights running.")
                        .rText(.inkCard)
                        .foregroundStyle(RColor.textPrimary)
                } skeleton: {
                    RSkeleton(bars: [nil, 150])
                }
                .frame(maxWidth: .infinity, minHeight: RDimension.sizeBriefCardMinHeight, alignment: .topLeading)
                .padding(RDimension.space4)
                .rRaised()
                .id(loadCount)
                HStack(spacing: RDimension.space2) {
                    RPill(title: "0.3s", style: .raised) { load(.milliseconds(300)) }
                    RPill(title: "2s", style: .raised) { load(.seconds(2)) }
                    RPill(title: "10s", style: .raised) { load(.seconds(10)) }
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-DesignLabAutoplay") else { return }
            for duration: Duration in [.milliseconds(300), .seconds(2), .seconds(10)] {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                await run(duration)
            }
        }
    }

    private func load(_ duration: Duration) {
        current?.cancel()
        current = Task { await run(duration) }
    }

    private func run(_ duration: Duration) async {
        loadCount += 1
        label = "loading for \(duration)"
        loading = true
        do { try await Task.sleep(for: duration) } catch { return }
        loading = false
        label = "loaded"
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.label).foregroundStyle(RColor.textLabel)
    }
}

#Preview("skeleton") { RSkeletonGallery() }
#endif
