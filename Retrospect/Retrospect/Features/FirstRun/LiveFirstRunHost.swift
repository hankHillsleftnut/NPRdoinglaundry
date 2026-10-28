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

    /// What the host shows for the seam it finds (pure, so the branches are tested).
    enum Content: Equatable {
        /// No seam: the person's store could not be opened; the retry page.
        case storeFailed
        /// The seam is still reading the kept answers: the canvas.
        case loading
        /// The questions.
        case questions

        @MainActor static func choose(seam: LiveFirstRunData?) -> Content {
            guard let seam else { return .storeFailed }
            return seam.isLoaded ? .questions : .loading
        }
    }

    /// The first run is over: the root marks it done and shows the journal.
    let onDone: () -> Void
    @Environment(Platform.AppEnvironment.self) private var platform

    var body: some View {
        switch Content.choose(seam: platform.firstRun) {
        case .questions:
            if let seam = platform.firstRun {
                QuestionsPageContainer(data: seam, kept: seam.kept, seamFinished: seam.completeQueued, onDone: onDone)
                    .accessibilityIdentifier("firstrun.questions")
            }
        case .loading:
            // the kept answers are being read: the canvas, never the first question for a person who is past it
            RColor.backgroundCanvas.ignoresSafeArea()
                .task { await platform.firstRun?.open() }
        case .storeFailed:
            StoreFailedView { platform.retryOpeningStore() }
        }
    }
}
