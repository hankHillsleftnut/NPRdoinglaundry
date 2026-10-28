//
//  Session+Access.swift
//  FR.b1.data: an access state written for one person only. The first run's `complete` receipt lands for the
//  person who answered; one that arrives after someone else signed in changes nothing. (In its own file: the
//  manager is at the file-length cap.)
//
import Foundation

extension Session.Manager {
    /// `setAccess` for `userID` only: ignored when nobody, or someone else, is signed in. Runs inside the actor,
    /// so the check and the write are not interleaved with a sign-in from outside.
    func setAccess(_ access: Session.AccessState, for userID: String) async {
        guard case let .signedIn(id, _) = await state, id == userID else { return }
        await setAccess(access)
    }
}
