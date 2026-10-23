@testable import Retrospect
import Testing

/// C41.4: what the 13 tiles accept, and how a code reads aloud.
struct TicketCodeTests {
    @Test("typing 7kq2-m9xd-4rta-b fills the tiles as 7KQ2M9XD4RTAB")
    func typed() {
        #expect(TicketCode.tiles(from: "7kq2-m9xd-4rta-b") == "7KQ2M9XD4RTAB")
    }

    @Test("O reads as 0, I and L as 1, and nothing else gets in")
    func alphabet() {
        #expect(TicketCode.tiles(from: "oil") == "011")
        #expect(TicketCode.tiles(from: "u!? ") == "")
        #expect(TicketCode.tiles(from: "7KQ2M9XD4RTABEXTRA") == "7KQ2M9XD4RTAB")
    }

    @Test("a pasted code with dashes and spaces fills all 13 tiles")
    func pasted() {
        #expect(TicketCode.tiles(from: " 7KQ2 - M9XD - 4RTA - B ").count == TicketCode.length)
    }

    @Test("the tiles group 4 4 4 1 and are spelled out for VoiceOver")
    func grouping() {
        #expect(TicketCode.groups(of: "7KQ2M9XD4RTAB") == ["7KQ2", "M9XD", "4RTA", "B"])
        #expect(TicketCode.groups(of: "7KQ") == ["7KQ", "", "", ""])
        #expect(TicketCode.spelled("7KQ") == "7 K Q")
    }

    @Test("a ticket's date and serial read as printed")
    func face() {
        #expect(TicketText.date("2026-10-19") == "19 oct 2026")
        #expect(TicketText.date("nonsense") == "nonsense")
        #expect(TicketText.serial(412) == "no. 0412")
        #expect(TicketText.serial(12345) == "no. 12345")
    }
}
