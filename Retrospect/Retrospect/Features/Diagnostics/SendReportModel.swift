//
//  SendReportModel.swift
//  DG.6: the state behind the "send a report" sheet (docs/team/flows/diagnostics.md). The
//  sheet shows what a report would hold (counts), takes an optional note, and queues the
//  report; the outbox sends it, so offline is fine. Nothing here touches a view or a
//  network: it talks only to `Flows.ReportSending`.
//
import Foundation
import Observation

@MainActor @Observable
final class SendReportModel {
    enum Phase: Equatable {
        case editing
        case sending
        /// Not saved; the same button tries again.
        case failed
        case queued(online: Bool)
    }

    /// The door's limit on the note (`Report.maxNoteCharacters`).
    static let maxNoteCharacters = Platform.Diagnostics.Report.maxNoteCharacters

    private(set) var included: Flows.ReportIncluded?
    private(set) var phase: Phase = .editing
    var note = "" {
        didSet {
            if note.count > Self.maxNoteCharacters {
                note = String(note.prefix(Self.maxNoteCharacters))
            }
        }
    }

    private let sender: any Flows.ReportSending
    private let done: (Flows.ReportOutcome) -> Void

    /// `done` runs once, when the report is saved on the phone.
    init(sender: any Flows.ReportSending, done: @escaping (Flows.ReportOutcome) -> Void) {
        self.sender = sender
        self.done = done
    }

    var canSend: Bool {
        phase == .editing || phase == .failed
    }

    func load() async {
        included = await sender.included()
    }

    func send() async {
        guard canSend else { return }
        phase = .sending
        let outcome = await sender.send(note: note)
        switch outcome {
        case let .queued(_, online):
            phase = .queued(online: online)
            done(outcome)
        case .failed:
            phase = .failed
        }
    }
}
