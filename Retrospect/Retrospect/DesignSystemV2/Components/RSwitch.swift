//
//  RSwitch.swift
//  M14 C07: the switch (Paper approvals · part 25 "switch · segmented"; switch.md). A sunken
//  track with a raised thumb; on is ink, not blue (founder's note on the part). No pending
//  state: the switch moves at once, the parent saves, and if saving fails the parent sets the
//  value back; the thumb springs home with haptic.error and the row's subline says why.
//  Held, the thumb stretches toward its travel (27 → 33). Tap toggles; a sideways drag past
//  half the travel sets the side it ends on.
//
import SwiftUI

struct RSwitch: View {
    /// What the switch controls, read by VoiceOver ("autoplay the next episode, switch, on").
    let label: String
    @Binding var isOn: Bool
    var isDisabled = false

    @State private var held = false
    /// The value your last touch chose. If the parent later sets anything else, saving failed.
    @State private var chosen: Bool?
    @State private var selectTick = 0
    @State private var errorTick = 0
    /// Dynamic Type grows the hit area; the track stays 51 × 31 (part 25).
    @ScaledMetric(relativeTo: .body) private var hitHeight = RDimension.sizeTouchTarget
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RSwitchTrack(isOn: isOn, marks: contrast == .increased)
            RSwitchThumb()
                .frame(width: held ? RDimension.sizeSwitchThumbHeld : RDimension.sizeSwitchThumb, height: RDimension.sizeSwitchThumb)
                .padding(RDimension.sizeBorderRing)
        }
        .frame(width: RDimension.sizeSwitchWidth, height: RDimension.sizeSwitchHeight)
        // the thumb on motion.spring.snappy (toggles, motion-system.md §3); Reduce Motion: instant
        .animation(reduceMotion ? nil : RMotion.snappy, value: isOn)
        .animation(reduceMotion ? nil : RMotion.snappy, value: held)
        // fade the switch as one layer (as Paper's opacity does), so the track never shows through the thumb
        .compositingGroup()
        .opacity(isDisabled ? RNumber.opacityDisabled : 1)
        // at least 44 tall around the 31 track, padding the frame, never the visual (craft 1.7)
        .frame(minHeight: hitHeight)
        .contentShape(Rectangle())
        .gesture(isDisabled ? nil : press)
        .onChange(of: isOn) { _, now in
            if let chosen, now != chosen {
                errorTick += 1
                self.chosen = nil
            }
        }
        // a failed save sets the value back within moments; after that, a change from elsewhere
        // (a sync, another device) is not a failure and must not buzz
        .task(id: chosen) {
            guard chosen != nil else { return }
            try? await Task.sleep(for: .seconds(RNumber.motionDurationToastVisible))
            if !Task.isCancelled {
                chosen = nil
            }
        }
        .sensoryFeedback(RHaptic.select, trigger: selectTick)
        .sensoryFeedback(RHaptic.error, trigger: errorTick)
        .accessibilityRepresentation {
            Toggle(label, isOn: $isOn).disabled(isDisabled)
        }
    }

    /// Down: the thumb stretches. Up: a tap toggles; a sideways drag past half the travel sets the side it ends on.
    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in held = true }
            .onEnded { value in
                held = false
                let travel = RDimension.sizeSwitchWidth - RDimension.sizeSwitchThumb - 2 * RDimension.sizeBorderRing
                let next = abs(value.translation.width) > travel / 2 ? value.translation.width > 0 : !isOn
                guard next != isOn else { return }
                chosen = next
                isOn = next
                selectTick += 1
            }
    }
}

/// Off: surface.track with the sunken shade and a 0.5pt inner hairline. On: ink with a 0 1 1 inset,
/// so it still reads as a channel. The colour cross-fades over 200ms while the thumb springs.
private struct RSwitchTrack: View {
    let isOn: Bool
    /// Increase Contrast adds the system's I / O marks in the open side of the track (part 25).
    let marks: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            shape.fill(RColor.surfaceTrack)
                // inset 0 1 2 depth.shadow.sunken
                .overlay(shape.stroke(RColor.depthShadowSunken, lineWidth: 2).blur(radius: 1).offset(y: 1).clipShape(shape))
                .overlay(shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderHairline))
            shape.fill(RColor.inkDefault)
                // inset 0 1 1 shadow.inkAction.1
                .overlay(shape.stroke(RColor.shadowInkAction1, lineWidth: 1).blur(radius: 0.5).offset(y: 1).clipShape(shape))
                .opacity(isOn ? 1 : 0)
            if marks {
                mark
            }
        }
        .animation(reduceMotion ? nil : RMotion.standard(RNumber.motionDurationBase), value: isOn)
    }

    /// I when on (left of the thumb), O when off (right of it), centred in the open side.
    private var mark: some View {
        let open = RDimension.sizeSwitchWidth - RDimension.sizeSwitchThumb - 2 * RDimension.sizeBorderRing
        return Group {
            if isOn {
                Capsule(style: .continuous).fill(RColor.surfaceThumb)
                    .frame(width: RDimension.sizeBorderDefault, height: RDimension.space2 + RDimension.sizeBorderRing)
            } else {
                Circle().strokeBorder(RColor.textLabel, lineWidth: RDimension.sizeBorderDefault)
                    .frame(width: RDimension.space2, height: RDimension.space2)
            }
        }
        .frame(width: open)
        .padding(.horizontal, RDimension.sizeBorderRing)
        .frame(maxWidth: .infinity, alignment: isOn ? .leading : .trailing)
        .accessibilityHidden(true)
    }
}

/// surface.thumb, raised: 0 2 5 + 0 1 1 shadows and a darker underside (inset 0 −1 0).
private struct RSwitchThumb: View {
    var body: some View {
        let shape = Capsule(style: .continuous)
        shape.fill(RColor.surfaceThumb)
            .overlay(alignment: .bottom) {
                shape.strokeBorder(RColor.depthStrokeOuter, lineWidth: RDimension.sizeBorderDefault)
                    .mask(alignment: .bottom) { Rectangle().frame(height: RDimension.sizeBorderDefault) }
            }
            .shadow(color: RColor.shadowThumb1, radius: 2.5, y: 2)
            .shadow(color: RColor.shadowThumb2, radius: 0.5, y: 1)
    }
}

#if DEBUG
struct RSwitchGallery: View {
    @State private var off = false
    @State private var on = true
    @State private var disabledOff = false
    @State private var disabledOn = true
    @State private var failing = false

    var body: some View {
        VStack(alignment: .leading, spacing: RDimension.space6) {
            Text("switch").rText(.labelMedium).foregroundStyle(RColor.textSecondary)
            HStack(spacing: RDimension.space6) {
                RSwitch(label: "off example", isOn: $off)
                RSwitch(label: "on example", isOn: $on)
                RSwitch(label: "disabled, off", isOn: $disabledOff, isDisabled: true)
                RSwitch(label: "disabled, on", isOn: $disabledOn, isDisabled: true)
            }
            HStack(spacing: RDimension.space3) {
                // saving always fails here: the switch moves, then springs home with haptic.error
                RSwitch(label: "fails to save", isOn: $failing)
                    .onChange(of: failing) { _, now in
                        guard now else { return }
                        Task {
                            try? await Task.sleep(for: .seconds(RNumber.motionDurationSlow))
                            failing = false
                        }
                    }
                Text("fails to save, snaps back").rText(.label).foregroundStyle(RColor.textLabel)
            }
        }
        .padding(RDimension.spaceScreenMargin)
    }
}

#Preview("switch") { RSwitchGallery() }
#endif
