@testable import Retrospect
import Testing

/// C26: the panel's corner line, when the card has a play, and what VoiceOver reads, per state.
struct RBriefCardTests {
    @Test("the corner line carries the length when ready and 'played' once heard")
    func cornerLine() {
        #expect(RBriefCard.label(date: "tue 21 oct", length: "2 min", state: .rest) == "tue 21 oct · 2 min")
        #expect(RBriefCard.label(date: "tue 21 oct", length: "2 min", state: .starting) == "tue 21 oct · 2 min")
        #expect(RBriefCard.label(date: "tue 21 oct", length: "2 min", state: .played) == "tue 21 oct · played")
        #expect(RBriefCard.label(date: "tue 21 oct", length: nil, state: .rest) == "tue 21 oct")
    }

    @Test("a quiet day, being made, an error and offline show only the date")
    func cornerLineWithoutPlay() {
        for state in [RBriefCard.State.quiet, .making(readyBy: "8:30"), .error(message: "couldn't load today's brief"), .offline] {
            #expect(RBriefCard.label(date: "tue 21 oct", length: "2 min", state: state) == "tue 21 oct")
        }
    }

    @Test("only a ready, starting or played brief has a play")
    func hasPlay() {
        #expect(RBriefCard.hasPlay(.rest))
        #expect(RBriefCard.hasPlay(.starting))
        #expect(RBriefCard.hasPlay(.played))
        #expect(!RBriefCard.hasPlay(.quiet))
        #expect(!RBriefCard.hasPlay(.making(readyBy: nil)))
        #expect(!RBriefCard.hasPlay(.error(message: "couldn't load today's brief")))
        #expect(!RBriefCard.hasPlay(.offline))
    }

    @Test("VoiceOver hears the headline, the length and the state")
    func spoken() {
        let headline = "three things moved since yesterday"
        #expect(RBriefCard.spoken(length: "2 min", headline: headline, state: .rest) == "today's brief, three things moved since yesterday, 2 min")
        #expect(RBriefCard.spoken(length: "2 min", headline: headline, state: .played) == "today's brief, three things moved since yesterday, played")
        #expect(RBriefCard.spoken(length: nil, headline: headline, state: .making(readyBy: "8:30")) == "today's brief, being made, ready by 8:30")
        #expect(RBriefCard.spoken(length: nil, headline: headline, state: .making(readyBy: nil)) == "today's brief, being made")
        #expect(RBriefCard.spoken(length: nil, headline: headline, state: .offline) == "today's brief, it'll be here when you're back online")
    }

    @Test("the play overhangs the seam by half its height, and the SE band is shorter than the panel")
    func geometry() {
        #expect(RBriefCard.playOverhang == RDimension.sizeControlDefault / 2)
        #expect(RBriefCard.panelHeightCompact < RBriefCard.panelHeight)
    }
}
