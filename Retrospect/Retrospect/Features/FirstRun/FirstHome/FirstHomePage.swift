//
//  FirstHomePage.swift
//  FH.home, ON-13 first home (Paper p-J-0 1FI8-0): JR-1's journal page on its first day (extended, not
//  forked: JournalPage draws the ready first episode, the welcome and the setup recap when given a
//  `FirstDay`), with the drawer button drawn but inert (FH-Q6 A) and the mic hidden (FH-Q5 A, JR-1's
//  default). The first episode's card opens the player sheet over the page and plays the tease from the
//  start (FH-Q3 A); collapsing it comes back here. The tab bar is the shell's (FH.home.b, waiting on the
//  founder's yes). Sample data only.
//
import SwiftUI

struct FirstHomePage: View {
    let recap: SetupRecap
    /// Pop the episode card once (the first time first home shows).
    var celebrate = false
    /// The local day for the journal, `YYYY-MM-DD`.
    let today: String
    /// Builds the player for the first episode each time the card is played.
    let makePlayer: (_ onCollapse: @escaping () -> Void) -> PlayerSheetModel

    @State private var player: PlayerSheetModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            JournalPageContainer(
                today: today,
                openDrawer: nil,
                firstDay: FirstDay(recap: recap, celebrate: celebrate, play: openPlayer)
            )
            .accessibilityHidden(player != nil)
            if let player {
                PlayerSheetScreen {
                    PlayerSheet(model: player)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(reduceMotion ? RMotion.standard(RNumber.motionDurationFast) : RMotion.sheet, value: player != nil)
        .accessibilityIdentifier("screen.ON-13")
    }

    private func openPlayer() {
        guard player == nil else { return }
        player = makePlayer { player = nil }
    }
}
