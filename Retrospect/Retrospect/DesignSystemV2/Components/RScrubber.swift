//
//  RScrubber.swift
//  C25: the player's scrubber (Paper JR-2 `1FN7-0`, track `1FNE-0`, thumb `1FND-0`, times
//  `1FN8-0`; held state from part 09 `A3D-0`). One capsule per part with 4pt gaps (one capsule
//  under a minute), the played fill inside each capsule, a 12pt raised thumb whose x always comes
//  from the playback fraction, and elapsed · part · remaining under it.
//
//  Hold and slide: the thumb grows to 20 and a bubble names the part; crossing into a part ticks
//  once per part crossed; a scrub within 12pt of a part's start lands on the start; dragging off
//  the line slows it (half past 50pt, a quarter past 100pt). The audio seeks only on release, so
//  the live player is never thrashed mid-drag. Built against `Flows.Playback` only.
//
import SwiftUI

// MARK: - Maths (pure)

/// Time <-> x on a track of part capsules with gaps between them. The gaps are not time: a time
/// maps into its own capsule, and an x inside a gap maps to the boundary between the two parts.
struct ScrubberMath: Equatable {
    struct Segment: Equatable {
        let start: Double
        let end: Double
        let x: CGFloat
        let width: CGFloat
    }

    /// A brief shorter than this is one capsule: its parts are too short to draw apart.
    static let oneCapsuleUnder: Double = 60

    let width: CGFloat
    let duration: Double
    let gap: CGFloat
    /// Where each part starts, in seconds, in order, the first at 0.
    let partStarts: [Double]
    let segments: [Segment]

    init(width: CGFloat, duration: Double, partStarts: [Double], gap: CGFloat = RDimension.space1) {
        let width = max(width, 0)
        let duration = max(duration, 0)
        self.width = width
        self.duration = duration
        self.gap = gap
        let inner = Array(Set(partStarts.filter { $0 > 0 && $0 < duration })).sorted()
        self.partStarts = [0] + inner
        let cuts = duration < Self.oneCapsuleUnder ? [] : inner
        let bounds = [0] + cuts + [duration]
        let count = bounds.count - 1
        let usable = max(width - gap * CGFloat(count - 1), 0)
        var x: CGFloat = 0
        var segments: [Segment] = []
        for index in 0 ..< count {
            let length = bounds[index + 1] - bounds[index]
            let segmentWidth = duration > 0 ? usable * CGFloat(length / duration) : usable
            segments.append(Segment(start: bounds[index], end: bounds[index + 1], x: x, width: segmentWidth))
            x += segmentWidth + gap
        }
        self.segments = segments
    }

    /// The x of a time, inside its own capsule.
    func x(at time: Double) -> CGFloat {
        guard duration > 0 else { return 0 }
        let time = min(max(time, 0), duration)
        let segment = segments.last { $0.start <= time } ?? segments[0]
        let length = segment.end - segment.start
        guard length > 0 else { return segment.x }
        return segment.x + segment.width * CGFloat((time - segment.start) / length)
    }

    /// The time under an x; an x in a gap is the boundary time.
    func time(at x: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let x = min(max(x, 0), width)
        for segment in segments where x <= segment.x + segment.width {
            // in the gap before a capsule: the boundary (the previous capsule ends where this starts)
            guard x > segment.x, segment.width > 0 else { return segment.start }
            return segment.start + Double((x - segment.x) / segment.width) * (segment.end - segment.start)
        }
        return duration
    }

    func fraction(at x: CGFloat) -> Double {
        duration > 0 ? time(at: x) / duration : 0
    }

    func x(atFraction fraction: Double) -> CGFloat {
        x(at: fraction * duration)
    }

    /// The part a time is in, from 0.
    func part(at time: Double) -> Int {
        partStarts.lastIndex { $0 <= time } ?? 0
    }

    /// A time within `RDimension.motionGestureScrubSnap` of a part's start lands on the start.
    func snapped(_ time: Double) -> Double {
        let at = x(at: time)
        let nearest = partStarts.min { abs(x(at: $0) - at) < abs(x(at: $1) - at) }
        guard let nearest, abs(x(at: nearest) - at) <= RDimension.motionGestureScrubSnap else { return time }
        return nearest
    }

    /// How fast the thumb follows the finger, by how far the finger has left the line: whole,
    /// half past one fine step, a quarter past two (the iOS scrubbing rule).
    static func rate(forVerticalOffset offset: CGFloat) -> CGFloat {
        let distance = abs(offset)
        let step = RDimension.motionGestureScrubFineStep
        if distance > step * 2 {
            return 0.25
        }
        return distance > step ? 0.5 : 1
    }
}

// MARK: - One held scrub (pure)

/// A finger on the track: where the thumb is, which part it is in, and how many parts it crossed.
struct ScrubDrag: Equatable {
    let math: ScrubberMath
    let start: CGPoint
    private(set) var x: CGFloat
    private(set) var part: Int
    private var lastFingerX: CGFloat

    init(math: ScrubberMath, finger: CGPoint) {
        self.math = math
        start = finger
        x = min(max(finger.x, 0), math.width)
        lastFingerX = finger.x
        part = 0
        part = math.part(at: time)
    }

    /// The time the thumb shows, snapped to a part's start when close.
    var time: Double {
        math.snapped(math.time(at: x))
    }

    /// Follows the finger at the rate its distance from the line allows. Returns how many parts
    /// the thumb crossed in this move (two parts in one fast move is two).
    mutating func move(to finger: CGPoint) -> Int {
        let rate = ScrubberMath.rate(forVerticalOffset: finger.y - start.y)
        x = min(max(x + (finger.x - lastFingerX) * rate, 0), math.width)
        lastFingerX = finger.x
        let now = math.part(at: time)
        let crossed = abs(now - part)
        part = now
        return crossed
    }
}

/// The scrubber's hold: the drag, the ticks it owes, and the one seek on release.
@MainActor @Observable
final class ScrubController {
    private(set) var drag: ScrubDrag?
    /// The lab draws the held look at a time without a finger (screenshots); never set in the app.
    private(set) var heldPreview: Double?
    /// Every part crossed so far; the view plays one `chapterTick` for each.
    private(set) var ticks = 0
    @ObservationIgnored private var paid = 0

    var isHeld: Bool {
        drag != nil || heldPreview != nil
    }

    /// The time the held thumb shows; nil at rest (the thumb follows the player).
    var heldTime: Double? {
        drag?.time ?? heldPreview
    }

    /// A finger touched the track (a new touch replaces a hold the system never ended).
    func touch(at start: CGPoint, now finger: CGPoint, math: ScrubberMath) {
        if drag?.start != start || drag?.math != math {
            drag = ScrubDrag(math: math, finger: start)
        }
        guard var drag else { return }
        ticks += drag.move(to: finger)
        self.drag = drag
    }

    /// The finger lifted: the one seek of the whole scrub.
    func release(seeking playback: any Flows.Playback) {
        guard let drag else { return }
        self.drag = nil
        playback.seek(to: drag.time)
    }

    /// One owed tick, if any: the view calls this until it says no.
    func payTick() -> Bool {
        guard paid < ticks else { return false }
        paid += 1
        return true
    }

    func hold(at time: Double?) {
        heldPreview = time
    }
}

// MARK: - Words

enum ScrubberWords {
    /// "00:48", "03:22", "1:02:05".
    static func clock(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let rest = total % 60
        if hours > 0 {
            return "\(hours):" + two(minutes) + ":" + two(rest)
        }
        return two(minutes) + ":" + two(rest)
    }

    /// "−03:22", with a true minus.
    static func remaining(_ seconds: Double) -> String {
        "\u{2212}" + clock(seconds)
    }

    /// "1 of 3", or the part's own title for episodes ("1 of 3 · the article").
    static func partName(_ index: Int, of count: Int, title: String?) -> String {
        let place = "\(index + 1) of \(count)"
        return title.map { place + " · " + $0 } ?? place
    }

    /// The part's name in the given style: counted ("2 of 4 · the article"), or its title alone
    /// ("the first thing i noticed", Paper ON-11 26OI-0), counted when it has no title.
    static func partName(_ index: Int, of count: Int, title: String?, style: RScrubber.PartLabel) -> String {
        switch style {
        case .counted:
            partName(index, of: count, title: title)
        case .title:
            title ?? partName(index, of: count, title: nil)
        }
    }

    /// What VoiceOver reads: "4 minutes 12 seconds of 11 minutes 30, part 2 of 3".
    static func spoken(position: Double, duration: Double, part: Int?, parts: Int) -> String {
        var words = spoken(position, full: true) + " of " + spoken(duration, full: false)
        if let part, parts > 1 {
            words += ", part \(part + 1) of \(parts)"
        }
        return words
    }

    /// "4 minutes 12 seconds"; the total drops the last unit ("11 minutes 30").
    private static func spoken(_ seconds: Double, full: Bool) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let minutes = total / 60
        let rest = total % 60
        let secondWords = rest == 1 ? "1 second" : "\(rest) seconds"
        guard minutes > 0 else { return secondWords }
        let minuteWords = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        guard rest > 0 else { return minuteWords }
        return minuteWords + " " + (full ? secondWords : "\(rest)")
    }

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

extension RTextStyle {
    /// The player's elapsed and remaining times (Paper 1FNB-0, 1FN9-0: mono 13 on a 16 line).
    static let playerTime = RTextStyle(
        family: .mono,
        size: RDimension.fontSizePlayerTime,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.23,
        relativeTo: .caption
    )
    /// The part name between the times (Paper 1FNA-0: Geist 13 on a 16 line).
    static let playerPart = RTextStyle(
        family: .label,
        size: RDimension.fontSizePlayerTime,
        weight: .regular,
        tracking: RNumber.fontTrackingNone,
        leading: 1.23,
        relativeTo: .caption
    )
}

// MARK: - View

struct RScrubber: View {
    /// How the part between the times is named.
    enum PartLabel: Equatable, Sendable {
        /// "2 of 3", or "2 of 4 · the article" (JR-2).
        case counted
        /// The part's title alone (ON-11 26OI-0); counted when the part has no title.
        case title
    }

    let playback: any Flows.Playback
    let partLabel: PartLabel
    @State private var scrub: ScrubController

    /// `scrub` is for the lab's held look and for tests; the app lets the scrubber make its own.
    init(playback: any Flows.Playback, scrub: ScrubController? = nil, partLabel: PartLabel = .counted) {
        self.playback = playback
        self.partLabel = partLabel
        _scrub = State(initialValue: scrub ?? ScrubController())
    }

    /// How far the bubble sits above the track row's centre.
    private static let bubbleLift = RDimension.sizeControlSmall / 2 + RDimension.sizePlayerThumbHeld / 2 + RDimension.space2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var tickBeat = 0
    @State private var bubbleWidth: CGFloat = 0

    private var duration: Double? {
        playback.duration ?? playback.item?.durationSeconds
    }

    private var partStarts: [Double] {
        playback.item?.parts.map(\.startSeconds) ?? []
    }

    private var partCount: Int {
        max(playback.item?.parts.count ?? 0, 1)
    }

    /// Scrubbing needs audio that can seek.
    private var canScrub: Bool {
        guard duration != nil, playback.item != nil else { return false }
        switch playback.state {
        case .idle, .offline, .failed: return false
        default: return true
        }
    }

    /// The time the thumb and the times show: the finger's while held, the player's otherwise.
    private var shownTime: Double {
        scrub.heldTime ?? playback.position
    }

    var body: some View {
        VStack(spacing: RDimension.sizePlayerTimesGap) {
            track
                .frame(height: RDimension.sizePlayerTrackRow)
            times
                .opacity(duration == nil ? 0 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("position")
        .accessibilityValue(spokenValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: playback.skip(by: RTransport.backSeconds)
            case .decrement: playback.skip(by: -RTransport.backSeconds)
            @unknown default: break
            }
        }
        .sensoryFeedback(RHaptic.chapterTick, trigger: tickBeat)
        .task(id: scrub.ticks) {
            while scrub.payTick() {
                tickBeat += 1
                do {
                    try await Task.sleep(for: .seconds(RNumber.motionDurationInstant))
                } catch {
                    return
                }
            }
        }
    }

    // MARK: Track

    private var track: some View {
        GeometryReader { geometry in
            let math = ScrubberMath(width: geometry.size.width, duration: duration ?? 0, partStarts: partStarts)
            let thumbX = math.x(at: shownTime)
            ZStack(alignment: .leading) {
                ForEach(Array(math.segments.enumerated()), id: \.offset) { _, segment in
                    capsule(segment, playedTo: duration == nil ? 0 : thumbX)
                }
                if duration != nil {
                    thumb
                        .position(x: thumbX, y: geometry.size.height / 2)
                    if scrub.isHeld {
                        bubble
                            .position(x: bubbleCentre(thumbX, width: geometry.size.width), y: geometry.size.height / 2 - Self.bubbleLift)
                            .transition(bubbleTransition)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay {
                Color.clear
                    .frame(width: geometry.size.width, height: RDimension.sizeTouchTarget)
                    .contentShape(Rectangle())
                    .gesture(drag(math: math))
                    .allowsHitTesting(canScrub)
            }
            .animation(reduceMotion ? nil : RMotion.snappy, value: scrub.isHeld)
            .animation(reduceMotion || scrub.drag != nil ? nil : RMotion.snappy, value: thumbX)
        }
    }

    private func capsule(_ segment: ScrubberMath.Segment, playedTo thumbX: CGFloat) -> some View {
        let played = min(max(thumbX - segment.x, 0), segment.width)
        return RShape.pill
            .fill(contrast == .increased ? RColor.surfaceStrong : RColor.surfaceTrack)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(RColor.playerProgress)
                    .frame(width: played)
            }
            .clipShape(RShape.pill)
            .frame(width: segment.width, height: RDimension.sizePlayerScrubber)
            .offset(x: segment.x)
    }

    private var thumb: some View {
        let size = scrub.isHeld ? RDimension.sizePlayerThumbHeld : RDimension.sizePlayerThumb
        return RShape.pill
            .fill(RColor.surfaceThumb)
            .overlay(RShape.pill.strokeBorder(RColor.depthStrokeInner, lineWidth: RDimension.sizeBorderHairline))
            .overlay(RShape.pill.stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            // Paper 1FND-0: contact 0 1 1.5, cast 0 4 10 −3 (the spread carried by a smaller radius)
            .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: scrub.isHeld ? 5 : 3.5, y: 4)
            .frame(width: size, height: size)
    }

    private var bubble: some View {
        Text(bubbleWords)
            .rText(.pill)
            .foregroundStyle(RColor.textPrimary)
            .lineLimit(1)
            .id(bubbleWords)
            .transition(reduceMotion ? .opacity : .push(from: .bottom))
            .animation(RMotion.standard(RNumber.motionDurationFast), value: bubbleWords)
            .padding(.horizontal, RDimension.space3)
            .frame(height: RDimension.sizeControlSmall)
            .rRaised(RDimension.radiusControl)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { bubbleWidth = $0 }
            .accessibilityHidden(true)
    }

    private var bubbleTransition: AnyTransition {
        if reduceMotion {
            return .opacity.animation(RMotion.standard(RNumber.motionDurationFast))
        }
        return .asymmetric(
            insertion: .offset(y: RDimension.motionAppearRise).combined(with: .opacity)
                .animation(RMotion.standard(RNumber.motionDurationScrubPreview)),
            removal: .offset(y: RDimension.motionAppearRise).combined(with: .opacity).animation(RMotion.popover)
        )
    }

    /// The bubble stays over the thumb but never past the track's ends.
    private func bubbleCentre(_ thumbX: CGFloat, width: CGFloat) -> CGFloat {
        let half = bubbleWidth / 2
        guard width > bubbleWidth else { return width / 2 }
        return min(max(thumbX, half), width - half)
    }

    private func drag(math: ScrubberMath) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                scrub.touch(at: value.startLocation, now: value.location, math: math)
            }
            .onEnded { _ in
                scrub.release(seeking: playback)
            }
    }

    // MARK: Times

    @ViewBuilder
    private var times: some View {
        let duration = duration ?? 0
        let elapsed = Text(ScrubberWords.clock(shownTime)).rText(.playerTime).foregroundStyle(RColor.textLabel)
        let remaining = Text(ScrubberWords.remaining(max(duration - shownTime, 0))).rText(.playerTime).foregroundStyle(RColor.textLabel)
        let part = Text(partWords).rText(.playerPart).foregroundStyle(RColor.textTertiary)
            .lineLimit(1)
            .opacity(scrub.isHeld ? 0 : 1)
            .animation(RMotion.standard(RNumber.motionDurationFast), value: scrub.isHeld)
        if dynamicTypeSize.isAccessibilitySize {
            // AX3: the times grow and stack, the part name under them
            VStack(alignment: .leading, spacing: RDimension.space1) {
                HStack {
                    elapsed
                    Spacer(minLength: RDimension.space2)
                    remaining
                }
                part
            }
        } else {
            HStack(spacing: RDimension.space2) {
                elapsed
                Spacer(minLength: 0)
                part
                Spacer(minLength: 0)
                remaining
            }
        }
    }

    private var currentPartIndex: Int {
        let math = ScrubberMath(width: 0, duration: duration ?? 0, partStarts: partStarts)
        return math.part(at: shownTime)
    }

    /// Empty for a brief of one part: there is nothing to count.
    private var partWords: String {
        guard partCount > 1 else { return "" }
        let index = currentPartIndex
        return ScrubberWords.partName(index, of: partCount, title: playback.item?.parts[safe: index]?.title, style: partLabel)
    }

    /// The bubble names the part; a one-part brief has no parts to name, so it shows the time.
    private var bubbleWords: String {
        partCount > 1 ? partWords : ScrubberWords.clock(shownTime)
    }

    private var spokenValue: String {
        guard let duration else { return "loading" }
        return ScrubberWords.spoken(position: shownTime, duration: duration, part: currentPartIndex, parts: partCount)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Lab

#if DEBUG
/// Lab page "scrubber": every sample scenario at rest, the held look, and a live one to drag.
struct RScrubberGallery: View {
    @State private var players = Flows.PlaybackScenario.allCases.map { SamplePlayback(scenario: $0, clock: ContinuousClock()) }
    @State private var held = ScrubController()
    @State private var heldPlayer = SamplePlayback(scenario: .briefPaused, clock: ContinuousClock())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                VStack(alignment: .leading, spacing: RDimension.space4) {
                    caption("held · 1:10, part 2 of 3")
                    RScrubber(playback: heldPlayer, scrub: held)
                        .padding(.top, RDimension.space8)
                }
                ForEach(players, id: \.scenario) { player in
                    VStack(alignment: .leading, spacing: RDimension.space4) {
                        caption(player.scenario.rawValue)
                        RScrubber(playback: player)
                    }
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
        .onAppear { held.hold(at: 70) }
        .accessibilityIdentifier("lab.scrubber")
    }

    private func caption(_ text: String) -> some View {
        Text(text).rText(.labelMedium).foregroundStyle(RColor.textSecondary)
    }
}

#Preview("scrubber") { RScrubberGallery() }
#endif
