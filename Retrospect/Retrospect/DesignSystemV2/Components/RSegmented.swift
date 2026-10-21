//
//  RSegmented.swift
//  M14 C08: the segmented control (Paper approvals · part 25 "switch · segmented";
//  c:segmented/{2,3}/{rest,disabled}). Pick one of two to five views at once. A sunken
//  underlay track, 36 tall with 2 padding; the chosen segment is a raised thumb, 32 tall;
//  no colour for the chosen one, only the thumb and text.primary (others text.label).
//  Segments are equal widths until a label doesn't fit, then they size to their labels.
//
import SwiftUI

extension RTextStyle {
    /// Segment labels (part 25: --font-label, --text-md, medium, --tracking-label, --leading-tight).
    static let segment = RTextStyle(
        family: .label,
        size: RDimension.fontSizeMd,
        weight: .medium,
        tracking: RNumber.fontTrackingLabel,
        leading: 1.1,
        relativeTo: .subheadline
    )
}

struct RSegmented<Value: Hashable>: View {
    /// What the control chooses, read by VoiceOver before the segments ("view").
    let label: String
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var isDisabled = false

    @Namespace private var thumb
    /// Dynamic Type grows the track (36) and keeps the 2 padding.
    @ScaledMetric(relativeTo: .subheadline) private var trackHeight = RDimension.sizeSearchField
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // equal widths; then each label's own width; at the largest sizes, labels shrink a little
        // rather than run past the track
        ViewThatFits(in: .horizontal) {
            segments(layout: AnyLayout(REqualWidthHStack()))
            segments(layout: AnyLayout(HStackLayout(spacing: .zero)))
            segments(layout: AnyLayout(RProportionalHStack()), shrinks: true)
        }
        .padding(RDimension.sizeBorderRing)
        .frame(height: trackHeight)
        .background { RSegmentedTrack() }
        // fade the control as one layer (as Paper's opacity does), so the track never shows through the thumb
        .compositingGroup()
        .opacity(isDisabled ? RNumber.opacityDisabled : 1)
        .disabled(isDisabled)
        // every segment's frame is 44 tall; the visual stays 36 (part 25 hit area)
        .frame(minHeight: RDimension.sizeTouchTarget)
        .sensoryFeedback(RHaptic.select, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func segments(layout: AnyLayout, shrinks: Bool = false) -> some View {
        layout {
            ForEach(options, id: \.value) { option in
                let chosen = option.value == selection
                Button {
                    guard !chosen else { return }
                    withAnimation(reduceMotion ? nil : RMotion.snappy) { selection = option.value }
                } label: {
                    Text(option.title)
                        .rText(.segment)
                        .foregroundStyle(chosen ? RColor.textPrimary : RColor.textLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(shrinks ? 0.7 : 1) // literal-ok: the smallest a label may shrink, accessibility sizes only
                        .fixedSize(horizontal: !shrinks, vertical: false)
                        .padding(.horizontal, shrinks ? RDimension.space2 : RDimension.space3)
                        // shrinking keeps each label's proportion, so no one label truncates first
                        .frame(maxWidth: shrinks ? nil : .infinity, maxHeight: .infinity)
                        .matchedGeometryEffect(id: option.value, in: thumb, isSource: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RSegmentStyle())
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        // one thumb that follows the chosen segment's frame, so it slides whole instead of
        // two thumbs cross-fading
        .background {
            RSegmentedThumb()
                .matchedGeometryEffect(id: selection, in: thumb, properties: .frame, isSource: false)
        }
    }
}

/// Pressed dims the touched label (part 25), at once, and back on release.
private struct RSegmentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? RNumber.opacityPressed : 1)
    }
}

/// background.underlay, sunken: inset 0 1 2 depth.shadow.sunken and a 0.5 inner hairline.
private struct RSegmentedTrack: View {
    var body: some View {
        let shape = Capsule(style: .continuous)
        shape.fill(RColor.backgroundUnderlay)
            .overlay(shape.stroke(RColor.depthShadowSunken, lineWidth: 2).blur(radius: 1).offset(y: 1).clipShape(shape))
            .overlay(shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
    }
}

/// background.raised with the double stroke (inner-top 0 1 0, inner 1, outer 0.5) and the
/// contact (0 1 1.5) and cast (0 2 4 −1) shadows.
private struct RSegmentedThumb: View {
    var body: some View {
        let shape = Capsule(style: .continuous)
        shape.fill(RColor.backgroundRaised)
            .overlay(shape.strokeBorder(RColor.depthStrokeInner, lineWidth: RDimension.sizeBorderDefault))
            .overlay(alignment: .top) {
                shape.strokeBorder(RColor.depthStrokeInnerTop, lineWidth: RDimension.sizeBorderDefault)
                    .mask(alignment: .top) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
            }
            .overlay(shape.stroke(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            .shadow(color: RColor.depthShadowContact, radius: 0.75, y: 1)
            .shadow(color: RColor.depthShadowCast, radius: 2, y: 2)
    }
}

/// Lays children out side by side at the widest child's width (Apple's equal-width stack).
/// Its ideal width is n × the widest, so ViewThatFits drops to natural widths when that doesn't fit.
private struct REqualWidthHStack: SwiftUI.Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? .zero
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? .zero
        let width = proposal.width ?? widest * CGFloat(subviews.count)
        return CGSize(width: max(width, widest * CGFloat(subviews.count)), height: proposal.height ?? height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard !subviews.isEmpty else { return }
        let width = bounds.width / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + width * CGFloat(index), y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
        }
    }
}

/// Gives every child the same share of its ideal width when they don't all fit, so labels
/// shrink together instead of one truncating while the others keep their size.
private struct RProportionalHStack: SwiftUI.Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let ideal = subviews.reduce(CGFloat.zero) { $0 + $1.sizeThatFits(.unspecified).width }
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? .zero
        return CGSize(width: min(ideal, proposal.width ?? ideal), height: proposal.height ?? height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let widths = subviews.map { $0.sizeThatFits(.unspecified).width }
        let total = widths.reduce(.zero, +)
        guard total > .zero else { return }
        let share = bounds.width / total
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width * share, height: bounds.height))
            x += width * share
        }
    }
}

#if DEBUG
struct RSegmentedGallery: View {
    @State private var range = "week"
    @State private var view = "chapters"
    @State private var length = "standard"

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            Text("segmented").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            RSegmented(label: "range", options: [("week", "week"), ("month", "month"), ("year", "year")], selection: $range)
            RSegmented(label: "view", options: [("transcript", "transcript"), ("chapters", "chapters")], selection: $view)
            RSegmented(
                label: "range",
                options: [("week", "week"), ("month", "month"), ("year", "year")],
                selection: .constant("month"),
                isDisabled: true
            )
            RSegmented(
                label: "brief length",
                options: [("short", "short"), ("standard", "standard"), ("long", "long")],
                selection: $length
            )
        }
        .frame(maxWidth: RDimension.layoutReadingWidth)
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("segmented") { RSegmentedGallery() }
#endif
