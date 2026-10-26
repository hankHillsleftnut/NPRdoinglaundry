@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// SAFE.audit: the real host, laid out in a real window on the test device. The page stays inside
/// the safe area; the sheet keeps main's geometry (top at the safe top + layout.sheetTop for full,
/// panel to the screen's bottom edge) and only its content stops above the home indicator; with
/// the keyboard up the strip is 0, so nothing is padded twice. (The real keyboard is checked on
/// the simulator: a test window gets no keyboard avoidance from a posted notification.)
@MainActor
@Suite(.serialized)
struct RSheetHostLayoutTests {
    /// Where the probes ended up, in window coordinates.
    @MainActor
    final class Probes {
        var pageBottom: CGRect?
        var sheetContent: CGRect?
    }

    private struct Harness: View {
        let detent: RSheetDetent
        let presented: Bool
        let probes: Probes

        var body: some View {
            RSheetHost {
                VStack(spacing: RDimension.space0) {
                    Spacer(minLength: RDimension.space0)
                    Color.clear
                        .frame(height: RDimension.sizeBorderDefault)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probes.pageBottom = $0 }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RColor.backgroundCanvas.ignoresSafeArea())
                .rSheet(isPresented: .constant(presented), detent: detent) {
                    Color.clear
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probes.sheetContent = $0 }
                }
            }
        }
    }

    /// Hosts the harness full screen and waits for both probes.
    private func layOut(_ detent: RSheetDetent, presented: Bool = true) async throws -> (UIWindow, Probes) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let probes = Probes()
        window.rootViewController = UIHostingController(rootView: Harness(detent: detent, presented: presented, probes: probes))
        window.makeKeyAndVisible()
        for _ in 0 ..< 100 where probes.pageBottom == nil || (presented && probes.sheetContent == nil) {
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(100))
        return (window, probes)
    }

    /// From the grabber's top padding to the content: layout.sheetTop + grabber + gap.
    private var grabberBlock: CGFloat {
        RDimension.layoutSheetTop + RDimension.sizeGrabberHeight + RDimension.layoutSheetGrabberGap
    }

    @Test("the page's last line sits on the safe area's bottom edge, above the home indicator")
    func pageStaysInSafeArea() async throws {
        let (window, probes) = try await layOut(.full, presented: false)
        defer { window.isHidden = true }
        let page = try #require(probes.pageBottom)
        #expect(abs(page.maxY - (window.bounds.height - window.safeAreaInsets.bottom)) < 1)
    }

    @Test("a full sheet keeps main's top (safe top + sheetTop); its content stops above the home indicator")
    func fullSheetGeometry() async throws {
        let (window, probes) = try await layOut(.full)
        defer { window.isHidden = true }
        let content = try #require(probes.sheetContent)
        let insets = window.safeAreaInsets
        #expect(abs(content.minY - (insets.top + RDimension.layoutSheetTop + grabberBlock)) < 1)
        // the panel is the content plus the home-indicator padding: it ends on the screen's edge
        #expect(abs(content.maxY + insets.bottom - window.bounds.height) < 1)
    }

    @Test("a medium sheet is half the host tall (host = screen less the status bar) and ends on the screen's edge")
    func mediumSheetGeometry() async throws {
        let (window, probes) = try await layOut(.medium)
        defer { window.isHidden = true }
        let content = try #require(probes.sheetContent)
        let insets = window.safeAreaInsets
        let hostHeight = window.bounds.height - insets.top
        let panelTop = window.bounds.height - hostHeight * RNumber.layoutSheetDetentMedium
        #expect(abs(content.minY - (panelTop + grabberBlock)) < 1)
        #expect(abs(content.maxY + insets.bottom - window.bounds.height) < 1)
    }

    @Test("the home-indicator strip: the host's height past the safe area; none while the keyboard is up")
    func homeIndicatorStrip() {
        // 17 Pro, keyboard down: host 812 (874 less the 62 status bar), safe area 778
        #expect(RSheetHostFrame(height: 812, safeHeight: 778).bottomInset == 34)
        // keyboard up: the host ends on the keyboard (812 - 336), well above the safe area's bottom
        #expect(RSheetHostFrame(height: 476, safeHeight: 778).bottomInset == 0)
        // SE: no strip; before the first measurement: nothing padded
        #expect(RSheetHostFrame(height: 647, safeHeight: 647).bottomInset == 0)
        #expect(RSheetHostFrame(height: 812, safeHeight: 0).bottomInset == 0)
    }
}
