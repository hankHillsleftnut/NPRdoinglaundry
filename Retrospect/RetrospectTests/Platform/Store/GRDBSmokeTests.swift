import GRDB
import Testing

@Suite(.timeLimit(.minutes(1)))
struct GRDBSmokeTests {
    @Test("GRDB opens an in-memory database in the test host")
    func grdbOpensAnInMemoryDatabase() throws {
        let queue = try DatabaseQueue()
        let foreignKeys = try queue.read { try Bool.fetchOne($0, sql: "PRAGMA foreign_keys") }
        try queue.write { try $0.execute(sql: "CREATE TABLE probe (id INTEGER PRIMARY KEY, value TEXT NOT NULL)") }
        try queue.write { try $0.execute(sql: "INSERT INTO probe (value) VALUES (?)", arguments: ["invented"]) }

        #expect(try queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM probe") } == 1)
        #expect(foreignKeys == true)
    }
}
