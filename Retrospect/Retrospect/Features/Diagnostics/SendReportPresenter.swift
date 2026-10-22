//
//  SendReportPresenter.swift
//  DG.6: where the sheet, its toast and the shake come together. `.sendReport()` goes once on a
//  tab's root, inside `RSheetHost`: it presents the sheet (on the tab's sheet host), floats the
//  toast ("sending…", then "sent. thank you." with the reference once the server has the
//  report, or "saved" when offline), opens the sheet on a shake while the switch is on, and puts
//  `openSendReport` in the environment so a settings row can open it.
//
import SwiftUI

@MainActor @Observable
final class SendReportCoordinator {
    var isPresented = false
    var toast: RToastItem?
    private(set) var model: SendReportModel?
    private var sender: (any Flows.ReportSending)?

    func attach(_ sender: (any Flows.ReportSending)?) {
        self.sender = sender
    }

    func open() {
        guard let sender, !isPresented else { return }
        model = SendReportModel(sender: sender) { [weak self] outcome in
            self?.queued(outcome)
        }
        isPresented = true
    }

    private func queued(_ outcome: Flows.ReportOutcome) {
        guard case let .queued(_, online) = outcome else { return }
        isPresented = false
        toast = online
            ? RToastItem(message: "sending your report", symbol: "arrow.up")
            : RToastItem(message: "saved. it'll send when you're back online.", symbol: "tray")
    }

    /// Shows the reference as each report is delivered; ends with the view.
    func listen() async {
        guard let sender else { return }
        for await receipt in sender.receipts() {
            toast = RToastItem(message: "sent. thank you. \(receipt.reference)", symbol: "checkmark")
        }
    }
}

private struct SendReportPresenter: ViewModifier {
    let bottomInset: CGFloat
    @Environment(\.reportSender) private var sender
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ShakePreference.key) private var shakeOn = ShakePreference.defaultValue
    @State private var coordinator = SendReportCoordinator()
    @State private var monitor = ShakeMonitor()

    func body(content: Content) -> some View {
        @Bindable var coordinator = coordinator
        content
            .environment(\.openSendReport) { coordinator.open() }
            .rSheet(isPresented: $coordinator.isPresented, detent: .full) {
                if let model = coordinator.model {
                    SendReportSheet(model: model)
                }
            }
            .rToast($coordinator.toast, bottomInset: bottomInset)
            .task(id: sender == nil ? 0 : 1) {
                coordinator.attach(sender)
                await coordinator.listen()
            }
            .task(id: shakeOn && scenePhase == .active) {
                if shakeOn, scenePhase == .active {
                    monitor.start { coordinator.open() }
                } else {
                    monitor.stop()
                }
            }
    }
}

extension View {
    /// The "send a report" sheet, its toast and the shake trigger, for the tab this view roots.
    /// `bottomInset` is the toast's distance above the bottom edge (12 above the tab bar).
    func sendReport(bottomInset: CGFloat) -> some View {
        modifier(SendReportPresenter(bottomInset: bottomInset))
    }
}
