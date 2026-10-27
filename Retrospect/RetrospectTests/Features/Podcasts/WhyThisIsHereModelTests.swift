import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WhyThisIsHereModelTests {
    @Test("asked, word for word as Paper draws PC-3 (1FXG-0)")
    func asked() {
        let content = SampleWhy.content(.asked)
        #expect(content.kind == .asked)
        #expect(content.claim == "are mornings when you do your best work?")
        #expect(content.meta == "asked · fairly sure · rests on 3 mornings")
        #expect(content.evidence.map(\.meta) == ["14 oct · your words", "16 oct · your words", "17 oct · calendar"])
        #expect(content.momentLabel == "where retro asks it")
        #expect(content.moment?.at == "at 4:12 in this week's")
    }

    @Test("stated, as 05 NBD-0 draws it: Retro says it")
    func stated() {
        let content = SampleWhy.content(.stated)
        #expect(content.kind == .stated)
        #expect(content.claim == "your best days start early.")
        #expect(content.momentLabel == "where retro says it")
    }

    @Test("\"and n more\" only when there are sources beyond the rows shown")
    func moreLine() {
        #expect(WhyUndrawnLines.moreLine(SampleWhy.content(.more).more) == "and 2 more")
        #expect(WhyUndrawnLines.moreLine(SampleWhy.content(.asked).more) == nil)
    }

    @Test("hear it plays the player at the moment's second; with no player it does nothing")
    func hearIt() {
        var heard: [Double] = []
        WhyThisIsHereModel(content: SampleWhy.content(.asked), dismiss: {}) { heard.append($0) }.playMoment()
        #expect(heard == [252])
        WhyThisIsHereModel(content: SampleWhy.content(.asked), dismiss: {}).playMoment()
        #expect(heard == [252])
    }

    @Test("nothing to show: no rows, and the meta doesn't count sources it can't show")
    func nothingYet() {
        let content = SampleWhy.content(.nothingYet)
        #expect(content.evidence.isEmpty)
        #expect(content.meta == "asked · fairly sure")
    }
}
