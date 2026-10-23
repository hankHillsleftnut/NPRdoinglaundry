import Foundation
import Observation

extension Platform {
    /// Whether an invite code is waiting in the Keychain for after sign-in (a link opened while signed out, or a
    /// typed code that could be used), so the app root can show the invite gate instead of plain sign-in.
    ///
    /// `hasCode` is nil until the first read: a root that is signed out must not flash the sign-in page for a
    /// moment and then switch to the gate. The code itself is only read through `code()`, for the stub's tiles;
    /// nothing here logs it.
    @MainActor @Observable
    final class PendingInvite {
        private(set) var hasCode: Bool?
        @ObservationIgnored private let read: @Sendable () async -> String?

        init(read: @escaping @Sendable () async -> String? = { nil }) {
            self.read = read
        }

        /// The waiting code, for the printed stub; nil when none (or the Keychain can't be read).
        func code() async -> String? {
            await read()
        }

        /// Reads the Keychain again: after a link arrives, a code is typed, a tear spends it, or the session moves.
        func refresh() async {
            let present = await read() != nil
            if hasCode != present {
                hasCode = present
            }
        }
    }
}
