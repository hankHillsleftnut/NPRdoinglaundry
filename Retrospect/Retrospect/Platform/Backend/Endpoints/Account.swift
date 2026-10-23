import Foundation

extension Backend {
    /// `DELETE /v2/account`'s body (contract 06 §8, fixture `account.delete.request`): the word "delete" and
    /// Apple's one-time code. The app always sends a fresh code (scope PL3.7g.min: always ask Apple); the server
    /// ignores it when it already holds a token, or while Apple revocation is off.
    struct AccountDeleteBody: Codable, Sendable, Equatable {
        static let confirmWord = "delete"

        let confirm: String
        let appleAuthorizationCode: String?

        init(appleAuthorizationCode: String?) {
            confirm = Self.confirmWord
            self.appleAuthorizationCode = appleAuthorizationCode
        }
    }

    /// The 202's answer (fixture `account.delete.response`): which deletion runs, and that it is running.
    struct AccountDeletion: Decodable, Sendable, Equatable {
        struct Deletion: Decodable, Sendable, Equatable {
            enum State: String, Flows.ContractEnum {
                case deleting, unknown
            }

            let id: String
            let state: State
        }

        let deletion: Deletion
    }
}

extension Backend.Endpoints {
    /// `DELETE /v2/account` (contract 06 §8): the server locks the account (every session ends at once), answers
    /// 202 and finishes in the background. Sent once, never retried: a second send after a lost answer meets a
    /// dead token, which the deletion reads as "under way" (`Session.AccountDeletion`).
    struct DeleteAccount: Backend.Endpoint {
        typealias Response = Backend.AccountDeletion

        let body: Backend.AccountDeleteBody?

        init(appleAuthorizationCode: String?) {
            body = Backend.AccountDeleteBody(appleAuthorizationCode: appleAuthorizationCode)
        }

        var method: Backend.Method {
            .delete
        }

        var path: Backend.PathTemplate {
            .account
        }

        /// The request waits for the lock and, with a code, one exchange with Apple (5 s on the server).
        var timeout: Duration {
            .seconds(30)
        }

        var retry: Backend.RetryPolicy {
            .never
        }
    }
}
