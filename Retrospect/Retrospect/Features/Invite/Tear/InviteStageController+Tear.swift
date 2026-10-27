//
//  InviteStageController+Tear.swift
//  TEAR.motion: the controller drives the tear's physics (TearSimulation). The page lays the ticket
//  out (`placeTear`), runs a clock only while the tear moves (`advanceTear`), and draws `tearFrame`.
//  The finger, the commit, the model's answer (the rip, or a spring back) and VoiceOver's action are
//  fed in here; the haptics fire from the simulation's own events, on the frame each one happens.
//  Under Reduce Motion there is no simulation: the hold, its ticks and the cross-fade stay as they were.
//
import CoreGraphics
import Foundation

extension InviteStageController {
    /// The ticket's size is known (or changed), and whether motion is on.
    func placeTear(_ geometry: TicketGeometry, reduceMotion: Bool) {
        guard !reduceMotion else {
            tear = nil
            tearFrame = nil
            moving = false
            return
        }
        if let tear, tear.perforation.width == geometry.width, tear.dropGap == TicketStage.dropGap(compact: geometry.compact) {
            return
        }
        // a new size mid-tear (rare: a rotation) starts the paper whole at that size
        let stubHeight = geometry.height - geometry.perforationY
        let dropGap = TicketStage.dropGap(compact: geometry.compact)
        if stillTear > 0 {
            let still = TearSimulation.still(
                progress: stillTear, width: geometry.width, perforationY: geometry.perforationY, stubHeight: stubHeight, dropGap: dropGap
            )
            tear = still
            tearFrame = still.frame
        } else {
            tear = TearSimulation(width: geometry.width, perforationY: geometry.perforationY, stubHeight: stubHeight, dropGap: dropGap)
            tearFrame = nil
        }
        heard = tear?.events.count ?? 0
        moving = false
    }

    /// One display frame: the paper catches up with the clock.
    func advanceTear() {
        guard stillTear == 0, var sim = tear else { return }
        sim.advance(to: clock())
        publish(sim)
    }

    /// Where the handle sits: under the finger while it drags (1:1), riding the run once committed.
    func handleX(width: CGFloat) -> CGFloat {
        if let tear, tear.isRunning || tear.phase == .sealing {
            return min(max(tear.finger, 0), width)
        }
        return tearProgress * width
    }

    // MARK: Inputs (called by the controller's own drag, commit, spring-back and action)

    func tearTouched(x: CGFloat, dy: CGFloat) {
        update { $0.touch(x: x, dy: dy) }
    }

    func tearReleased(velocity: CGFloat) {
        update { $0.commit(velocity: velocity) }
    }

    func tearSprangBack() {
        update { $0.springBack() }
    }

    func tearRunsByItself() {
        update { $0.autoRun() }
    }

    /// The model moved on: the redeem's answer snaps the last bridge; a new ticket starts whole.
    func tearPhaseChanged() {
        switch model.phase {
        case .torn:
            if let tear, stillTear == 0, tear.isRunning || tear.phase == .sealing {
                update { $0.rip() }
            } else {
                // Reduce Motion, a still, or a late redeem after the paper went whole: the two-state
                // drawing's cross-fade shows it, and the rip lands with it
                restartTear()
                rips += 1
            }
        case .typed, .printing, .promise, .signingIn, .waiting:
            restartTear()
        default:
            break
        }
    }

    // MARK: Plumbing

    /// The paper whole and still again (a new ticket, or the torn state drawn without the physics).
    private func restartTear() {
        guard stillTear == 0, let tear, tear.phase != .idle else { return }
        let fresh = TearSimulation(width: tear.perforation.width, perforationY: tear.perforationY, stubHeight: tear.stubHeight, dropGap: tear.dropGap)
        self.tear = fresh
        heard = 0
        tearFrame = nil
        moving = false
    }

    private func update(_ change: (inout TearSimulation) -> Void) {
        guard stillTear == 0, var sim = tear else { return }
        sim.advance(to: clock())
        change(&sim)
        publish(sim)
    }

    private func publish(_ sim: TearSimulation) {
        let fresh = sim.events.dropFirst(min(heard, sim.events.count))
        for (event, _) in fresh {
            switch event {
            case .tick: clicks += 1
            case .rip: rips += 1
            case .land: stubLandings += 1
            case .touchDown, .commit, .springBack: break
            }
        }
        heard = sim.events.count
        tear = sim
        tearFrame = sim.phase == .idle ? nil : sim.frame
        moving = !sim.isAtRest
    }

    static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) * 1e-18 // literal-ok: attoseconds to seconds
    }
}
