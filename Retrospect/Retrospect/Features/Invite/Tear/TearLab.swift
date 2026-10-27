//
//  TearLab.swift
//  TEAR.motion: the lab page "tear" (-DesignLab -DesignLabPage tear). The tear as main shipped it
//  before TEAR.motion ("current": the two-state TicketStage, driven by the calls the controller made)
//  next to the physical one the app now runs ("proposed": TearSimulation drawn by TicketStage's
//  TearTicket, the same view the invite page draws), on the same scripted finger so recordings line
//  up frame for frame, or on your own finger. Haptics fire as they would in the app; a small marker
//  under the ticket shows the frame each one fires on (the simulator has no haptics, recordings
//  need to see them).
//
//  Launch arguments (all optional): -TearLabMode current|proposed, -TearLabAuto YES (play the
//  script once on appear), -TearLabFreeze <s> (hold the clock at that script time, for stills),
//  -TearDroop <deg>, -TearRest <deg>, -TearRecoil <0…2>, -TearFlutter <0…2>.
//
#if DEBUG
import SwiftUI

struct TearLab: View {
    enum Mode: String, CaseIterable, Identifiable {
        case current, proposed
        var id: String {
            rawValue
        }
    }

    @State private var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "TearLabMode") ?? "") ?? .proposed
    @State private var take = 0
    @State private var auto = UserDefaults.standard.bool(forKey: "TearLabAuto")

    var body: some View {
        VStack(spacing: RDimension.space4) {
            HStack(spacing: RDimension.space3) {
                Picker("tear", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                RButton(title: "play", variant: .text) {
                    auto = true
                    take += 1
                }
                RButton(title: "reset", variant: .text) {
                    auto = false
                    take += 1
                }
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            GeometryReader { page in
                let geometry = TicketGeometry(width: min(page.size.width - RDimension.space6 * 2, 354), compact: false) // literal-ok: board width 354
                Group {
                    switch mode {
                    case .current: CurrentTear(geometry: geometry, scripted: auto)
                    case .proposed: ProposedTear(geometry: geometry, scripted: auto)
                    }
                }
                .id("\(mode.rawValue)-\(take)")
                .frame(maxWidth: .infinity)
                .padding(.top, RDimension.space4)
            }
        }
    }
}

private enum TearLabArgs {
    static func double(_ key: String) -> Double? {
        UserDefaults.standard.object(forKey: key) == nil ? nil : UserDefaults.standard.double(forKey: key)
    }

    static var freeze: Double? {
        double("TearLabFreeze")
    }

    static var parameters: TearParameters {
        var p = TearParameters.tokens
        if let droop = double("TearDroop") {
            p.droopMax = droop
        }
        if let rest = double("TearRest") {
            p.restAngle = rest
        }
        if let recoil = double("TearRecoil") {
            p.recoil = recoil
        }
        if let flutter = double("TearFlutter") {
            p.flutter = flutter
        }
        return p
    }
}

// MARK: - Haptic markers

/// Fires the haptics and shows, for a moment, which one fired on this frame.
private struct TearHapticRelay: View {
    let ticks: Int
    var clicks = 0
    let rips: Int
    let lands: Int
    let label: String?

    var body: some View {
        Text(label ?? " ")
            .rText(.labelMedium)
            .foregroundStyle(RColor.textSecondary)
            .frame(height: RDimension.sizeControlSmall)
            .sensoryFeedback(RHaptic.select, trigger: ticks)
            .sensoryFeedback(RHaptic.tearTick, trigger: clicks)
            .sensoryFeedback(RHaptic.rip, trigger: rips)
            .sensoryFeedback(RHaptic.tearLand, trigger: lands)
            .accessibilityHidden(true)
    }
}

// MARK: - Current (the shipping behaviour, the controller's own calls)

private struct CurrentTear: View {
    let geometry: TicketGeometry
    let scripted: Bool

    @State private var start = Date.now
    @State private var tearProgress: CGFloat = 0
    @State private var fallen = false
    @State private var dragging = false
    @State private var committedAt: Double?
    @State private var ticker = HoleTicker()
    @State private var ticks = 0
    @State private var rips = 0
    @State private var marker: (String, Double)?
    @State private var released = false
    /// The script time played up to (stepped at 240 Hz, so a frozen still replays the whole script).
    @State private var played = -TearScript.lead

    var body: some View {
        TimelineView(.animation) { context in
            let now = clock(context.date)
            VStack(spacing: RDimension.space4) {
                TicketStage(
                    geometry: geometry, face: SampleInvite.face, tiles: SampleInvite.code, date: "21 oct 2026",
                    tearProgress: tearProgress, stub: fallen ? .fallen : .joined
                )
                .animation(RMotion.settle, value: fallen)
                .overlay(alignment: .topLeading) {
                    RTicketHandle(held: dragging)
                        .offset(x: tearProgress * geometry.width - RDimension.sizeTouchTarget / 2, y: geometry.perforationY - RDimension.sizeTouchTarget / 2)
                        .opacity(fallen ? 0 : 1)
                        .gesture(scripted ? nil : drag)
                }
                .coordinateSpace(.named("tearlab"))
                TearHapticRelay(ticks: ticks, rips: rips, lands: 0, label: label(now))
                Spacer(minLength: 0)
            }
            .onChange(of: context.date) { _, date in
                if scripted {
                    var at = played
                    while at + 1.0 / 240 <= clock(date) - TearScript.lead {
                        at += 1.0 / 240
                        play(at)
                    }
                    played = at
                }
            }
        }
    }

    private func clock(_ date: Date) -> Double {
        if let freeze = TearLabArgs.freeze {
            return freeze + TearScript.lead
        }
        return date.timeIntervalSince(start)
    }

    private func label(_ now: Double) -> String? {
        guard let marker, now - marker.1 < 0.12 else { return nil } // literal-ok: marker visible ~7 frames
        return marker.0
    }

    private func play(_ t: Double) {
        if let committedAt {
            if !fallen, t - committedAt >= TearScript.redeem {
                fallen = true
                rips += 1
                marker = ("rip", t + TearScript.lead)
            }
            return
        }
        let finger = TearScript.finger(at: t, width: geometry.width)
        if finger.down {
            moved(x: finger.x, at: t)
        } else if t >= TearScript.releaseAt, dragging {
            lifted(x: finger.x, velocity: TearScript.releaseVelocity(width: geometry.width), at: t)
        }
    }

    private func moved(x: CGFloat, at t: Double) {
        if !dragging {
            dragging = true
            ticks += 1
            marker = ("tick", t + TearScript.lead)
        }
        let progress = TearMath(width: geometry.width).progress(x: x)
        tearProgress = progress
        if ticker.tick(progress: progress, at: .milliseconds(Int(t * 1000))) {
            ticks += 1
            marker = ("tick", t + TearScript.lead)
        }
    }

    private func lifted(x: CGFloat, velocity: CGFloat, at t: Double) {
        dragging = false
        let progress = TearMath(width: geometry.width).progress(x: x)
        if TearMath.commits(progress: progress, velocity: velocity) {
            withAnimation(RMotion.snappy) { tearProgress = 1 }
            committedAt = t
        } else {
            withAnimation(RMotion.snappy) { tearProgress = 0 }
            ticker.reset()
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("tearlab"))
            .onChanged { value in
                guard committedAt == nil, !released else { return }
                let t = Date.now.timeIntervalSince(start) - TearScript.lead
                moved(x: value.location.x, at: t)
            }
            .onEnded { value in
                guard committedAt == nil else { return }
                let t = Date.now.timeIntervalSince(start) - TearScript.lead
                lifted(x: value.location.x, velocity: value.velocity.width, at: t)
            }
    }
}

// MARK: - Proposed (TearPhysics)

private struct ProposedTear: View {
    let geometry: TicketGeometry
    let scripted: Bool

    @State private var start = Date.now
    @State private var sim: TearSimulation?
    @State private var ripDue: Double?

    var body: some View {
        TimelineView(.animation) { context in
            let model = sim ?? fresh
            VStack(spacing: RDimension.space4) {
                TicketStage(
                    geometry: geometry, face: SampleInvite.face, tiles: SampleInvite.code, date: "21 oct 2026",
                    stub: model.isSeparated ? .fallen : .joined, tear: model.frame
                )
                .animation(RMotion.settle, value: model.isSeparated)
                .overlay(alignment: .topLeading) {
                    RTicketHandle(held: model.phase == .dragging)
                        .offset(x: model.finger - RDimension.sizeTouchTarget / 2, y: geometry.perforationY - RDimension.sizeTouchTarget / 2)
                        .opacity(model.phase == .idle || model.phase == .dragging ? 1 : 0)
                        .animation(RMotion.standard(RNumber.motionDurationBase), value: model.phase == .dragging || model.phase == .idle)
                        .gesture(scripted ? nil : drag)
                }
                .coordinateSpace(.named("tearlab"))
                TearHapticRelay(
                    ticks: count(model) { $0 == .touchDown },
                    clicks: count(model, Self.isTick),
                    rips: count(model) { $0 == .rip },
                    lands: count(model) { $0 == .land },
                    label: label(model)
                )
                Spacer(minLength: 0)
            }
            .onChange(of: context.date) { _, date in advance(date) }
        }
    }

    private var fresh: TearSimulation {
        TearSimulation(
            p: TearLabArgs.parameters, width: geometry.width, perforationY: geometry.perforationY,
            stubHeight: geometry.height - geometry.perforationY, dropGap: TicketStage.dropGap(compact: geometry.compact)
        )
    }

    private static func isTick(_ event: TearEvent) -> Bool {
        switch event {
        case .tick: true
        default: false
        }
    }

    private func count(_ model: TearSimulation, _ match: (TearEvent) -> Bool) -> Int {
        model.events.filter { match($0.0) }.count
    }

    private func label(_ model: TearSimulation) -> String? {
        guard let last = model.events.last, model.time - last.1 < 0.12 else { return nil } // literal-ok: marker visible ~7 frames
        switch last.0 {
        case .touchDown, .tick: return "tick"
        case .rip: return "rip"
        case .land: return "land"
        case .commit, .springBack: return nil
        }
    }

    private func advance(_ date: Date) {
        var model = sim ?? fresh
        var due = ripDue
        let now = TearLabArgs.freeze.map { $0 + TearScript.lead } ?? date.timeIntervalSince(start)
        let t = now - TearScript.lead
        if scripted {
            // feed the finger at 240 Hz so the result never depends on the display's frame rate (and a
            // frozen still computes exactly the frame the recording shows at that time)
            var at = model.time - TearScript.lead
            while at + 1.0 / 240 <= t {
                at += 1.0 / 240
                feed(&model, at: at)
                model.advance(to: at + TearScript.lead)
                redeem(&model, due: &due)
            }
        } else {
            model.advance(to: now)
            redeem(&model, due: &due)
        }
        ripDue = due
        sim = model
    }

    /// The sample redeem answers 0.3 s after the commit: the last bridge snaps (on reaching it).
    private func redeem(_ model: inout TearSimulation, due: inout Double?) {
        if due == nil, model.phase == .sealing || isRunning(model) {
            due = model.time + TearScript.redeem
        }
        if let at = due, model.time >= at, model.phase == .sealing || isRunning(model) {
            model.rip()
        }
    }

    private func isRunning(_ model: TearSimulation) -> Bool {
        if case .running = model.phase {
            return true
        }
        return false
    }

    private func feed(_ model: inout TearSimulation, at t: Double) {
        let finger = TearScript.finger(at: t, width: geometry.width)
        if finger.down {
            model.touch(x: finger.x, dy: finger.dy)
        } else if t >= TearScript.releaseAt, model.phase == .dragging {
            model.release(velocity: TearScript.releaseVelocity(width: geometry.width))
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("tearlab"))
            .onChanged { value in
                var model = sim ?? fresh
                model.advance(to: Date.now.timeIntervalSince(start))
                model.touch(x: value.location.x, dy: value.location.y - geometry.perforationY)
                sim = model
            }
            .onEnded { value in
                var model = sim ?? fresh
                model.advance(to: Date.now.timeIntervalSince(start))
                model.release(velocity: value.velocity.width)
                sim = model
            }
    }
}

#Preview("tear lab") { TearLab() }
#endif
