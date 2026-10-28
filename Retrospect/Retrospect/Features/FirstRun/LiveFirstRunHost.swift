//
//  LiveFirstRunHost.swift
//  FR.b1.root (founder go 28 Oct, pipeline/screens/DECISIONS.md): the first run on the live root, between
//  "begin" and the journal. This bite hosts one step, the questions (ON-3–9), on the live seam the stack
//  built (`platform.firstRun`, FR.b1.data); later bites add privacy, getting ready, the tease, the paywall
//  and first home here, in the order `FlowPlan.edges` draws (a DEBUG test pins `Step` to that plan, so there
//  is no second route table). The seam's kept words are the page's `kept` (resume shows them); when the
//  seam is still reading them the canvas waits; when there is no seam (the store couldn't be opened) the
//  store-failed page offers a retry, as the journal's route does. Nothing here names a sample type.
//
import SwiftUI

struct LiveFirstRunHost: View {
    /// The first run's steps the live host has, in the app's order (the names are `FirstRunScreen`'s).
    enum Step: String, CaseIterable {
        /// ON-3–9.
        case questions
    }

    /// The first run is over: the root marks it done and shows the journal.
    let onDone: () -> Void
    @Environment(Platform.AppEnvironment.self) private var platform

    var body: some View {
        if let seam = platform.firstRun {
            if seam.isLoaded {
                QuestionsPageContainer(data: seam, kept: seam.kept, seamFinished: seam.completeQueued, onDone: onDone)
                    .accessibilityIdentifier("firstrun.questions")
            } else {
                // the kept answers are being read: the canvas, never the first question for a person who is past it
                RColor.backgroundCanvas.ignoresSafeArea()
                    .task { await seam.open() }
            }
        } else {
            StoreFailedView { platform.retryOpeningStore() }
        }
    }
}
