import Foundation

extension Session {
    /// Where the account stands (contract 00 §4). Read from every sign-in and
    /// refresh answer and kept with the session, so the gate can decide
    /// offline at launch. A state the app doesn't know decodes to `unknown`.
    enum AccessState: String, Flows.ContractEnum {
        case waitlisted, approved, member, staff, suspended, unknown
    }

    /// Who vouched for the person: which sign-in provider made the session.
    /// Kept with the session; `unknown` for an item saved before it was recorded.
    enum Provider: String, Flows.ContractEnum {
        case apple, google, unknown
    }
}
