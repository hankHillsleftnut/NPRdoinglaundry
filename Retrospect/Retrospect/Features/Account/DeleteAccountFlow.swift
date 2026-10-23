//
//  DeleteAccountFlow.swift
//  P31.delete: what the "delete account…" row, its dialog (C50.1 #4) and the goodbye (C50.2) need from the app,
//  as one seam. The live flow runs `Platform.AppEnvironment.deleteAccount` (PL3.7g.min); the sample flow runs the
//  same states on invented timing for the launcher. The views never delete anything themselves.
//
import Foundation
import Observation

/// Where a deletion stands, as the account page shows it.
enum DeleteAccountState: Equatable, Sendable {
    /// No dialog: the account page as it is.
    case closed
    /// The dialog is up and nothing has been pressed (or Apple's sheet was closed and the dialog came back).
    case asking
    /// "delete my account" was pressed: Apple's sheet, then the request. Cancel is disabled.
    case pending
    /// Nothing was deleted; the dialog says why, and "delete my account" works again.
    case failed(Session.DeletionProblem)
    /// The server has it: the goodbye page, then the phone is erased.
    case goodbye
    /// Erased and signed out: the root shows the first-time splash.
    case done
}

@MainActor
protocol DeleteAccountFlowing: AnyObject, Observable {
    var state: DeleteAccountState { get }
    /// Entries on the phone that haven't reached retrospect; they go with the account, and the dialog says so.
    var unsent: Int { get }
    /// False when the phone has no connection: the dialog's confirm is disabled with "needs a connection".
    var isOnline: Bool { get }
    /// The row was tapped: the dialog opens, with the unsent count and the connection read again.
    func open()
    /// "delete my account".
    func confirm()
    /// "cancel" (or the VoiceOver escape): closes the dialog, deletes nothing. Ignored while pending or after.
    func cancel()
}

extension DeleteAccountState {
    /// Whether the dialog is up.
    var showsDialog: Bool {
        switch self {
        case .asking, .pending, .failed: true
        case .closed, .goodbye, .done: false
        }
    }

    /// Whether the goodbye covers the page.
    var showsGoodbye: Bool {
        self == .goodbye || self == .done
    }
}
