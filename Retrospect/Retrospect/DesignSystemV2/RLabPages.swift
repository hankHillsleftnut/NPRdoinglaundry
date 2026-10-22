//
//  RLabPages.swift
//  The design lab's shell and its one list of pages (-DesignLab). Each page's view lives in its
//  own component file; adding a page is one line in `RLabPage.all`, in name order, so pages
//  built at the same time don't collide on the same lines. `-DesignLabPage <name>` opens one
//  directly (screenshots, recordings); `-DesignLabToast` still opens the toast page.
//
import SwiftUI

#if DEBUG
struct RLabPage: Identifiable {
    let id: String
    let view: () -> AnyView

    init(_ id: String, @ViewBuilder view: @escaping () -> some View) {
        self.id = id
        self.view = { AnyView(view()) }
    }

    /// Every page, in name order. Add a page as one line in its place.
    static let all: [RLabPage] = [
        RLabPage("artwork") { RArtworkLab() },
        RLabPage("brief") { RBriefCardGallery() },
        RLabPage("dialog") { RDialogGallery() },
        RLabPage("empty") { REmptyLineGallery() },
        RLabPage("entryrow") { REntryRowGallery() },
        RLabPage("error") { RErrorStateGallery() },
        RLabPage("evidence") { REvidenceRowGallery() },
        RLabPage("foundation") { RFoundationGallery() },
        RLabPage("guess") { RGuessCardGallery() },
        RLabPage("journal") { JournalLabPage() },
        RLabPage("journaldata") { SampleJournalGallery() },
        RLabPage("menu") { RMenuGallery() },
        RLabPage("message") { RMessageBubbleGallery() },
        RLabPage("motion") { RMotionLab() },
        RLabPage("offline") { ROfflineLineGallery() },
        RLabPage("parts") { RPartsLabPage() },
        RLabPage("report") { SendReportGallery() },
        RLabPage("retro") { RRetroLineGallery() },
        RLabPage("sheet") { RSheetHostGallery() },
        RLabPage("skeleton") { RSkeletonGallery() },
        RLabPage("toast") { RToastGallery() },
        RLabPage("topbar") { RTopBarGallery() },
        RLabPage("voice") { RVoiceBubbleGallery() },
    ]

    /// The page the lab opens on: `-DesignLabToast`, else `-DesignLabPage <name>`, else motion.
    static var launch: String {
        if ProcessInfo.processInfo.arguments.contains("-DesignLabToast") {
            return "toast"
        }
        let asked = UserDefaults.standard.string(forKey: "DesignLabPage")
        return all.contains { $0.id == asked } ? asked ?? "motion" : "motion"
    }
}

struct RDesignLab: View {
    @State private var pageId = RLabPage.launch

    var body: some View {
        VStack(spacing: RDimension.space0) {
            Picker("page", selection: $pageId) {
                ForEach(RLabPage.all) { Text($0.id).tag($0.id) }
            }
            .pickerStyle(.menu)
            .rText(.labelMedium)
            .tint(RColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .padding(.vertical, RDimension.space2)
            .accessibilityIdentifier("lab.page")
            if let page = RLabPage.all.first(where: { $0.id == pageId }) {
                page.view()
            }
        }
        .background(RColor.backgroundCanvas)
        .rLifeHost()
        .rReadsScreenHeight()
    }
}

/// The lab's "parts" page: both parts galleries in one scroll.
private struct RPartsLabPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                RParts1Gallery()
                RParts2Gallery()
            }
        }
    }
}

#Preview("design lab") { RDesignLab() }
#endif
