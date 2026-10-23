//
//  DeleteAccountDialog.swift
//  C50.1 #4: the delete-account dialog, `RDialog` (C19.2, part 24 `A5L-0`) with the copy from views.md C50.1. No
//  Paper drawing exists for this copy (C50.1 lists it "to confirm with the founder"). No billing paragraph: there
//  are no subscriptions yet. When entries haven't sent, the line says how many go with the account.
//
import SwiftUI

struct DeleteAccountDialog: View {
    let flow: any DeleteAccountFlowing

    static let title = "delete your account?"
    static let confirmTitle = "delete my account"

    /// What happens, exactly (C50.1 #4), plus what goes that never reached retrospect.
    static func line(unsent: Int) -> String {
        let base = "your account, entries, episodes and everything retro knows are deleted. this can't be undone."
        switch unsent {
        case 0: return base
        case 1: return base + " 1 entry that hasn't sent yet goes with it."
        default: return base + " \(unsent) entries that haven't sent yet go with it."
        }
    }

    /// The error line under the actions: what went wrong, and that nothing was deleted when that is known.
    static func message(for problem: Session.DeletionProblem) -> String {
        switch problem {
        case .differentAppleAccount: "that's a different apple account. nothing was deleted."
        case .appleRefused: "apple couldn't confirm it's you. nothing was deleted. try again."
        case .noAnswer: "retro couldn't be reached. try again."
        case .notNow: "retro couldn't delete your account just now. nothing was deleted. try again."
        }
    }

    static func status(for state: DeleteAccountState, isOnline: Bool) -> RDialog.Status {
        switch state {
        case .pending, .goodbye, .done: .pending
        case let .failed(problem): .error(message: message(for: problem))
        case .asking, .closed: isOnline ? .rest : .offline
        }
    }

    var body: some View {
        RDialog(
            title: Self.title,
            line: Self.line(unsent: flow.unsent),
            confirmTitle: Self.confirmTitle,
            cancelTitle: "cancel",
            status: Self.status(for: flow.state, isOnline: flow.isOnline),
            confirm: { flow.confirm() },
            cancel: { flow.cancel() }
        )
        .accessibilityIdentifier("account.delete.dialog")
    }
}
