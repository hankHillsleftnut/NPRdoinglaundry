@testable import Retrospect
import SwiftUI
import Testing
import UIKit

/// TYPE.leading: the ink titles' lines sit Paper's pitch apart (leading × size), the first line
/// stays where it was, and no existing type value changed.
@MainActor
struct RPaperPitchTests {
    /// Paper (file Retrospect, tokens e8f98ba6): --leading-tight 110% at --text-3xl 30, --text-2xl 28,
    /// --text-xl 22, --text-md 14, --text-hero 64; read 26 Oct from 26N1-0, 1F6V-0, 1F81-0, 218B-0,
    /// 26MF-0, 1FUO-0, 1FYA-0.
    struct PaperLine {
        let name: String
        let style: RTextStyle
        let lineHeight: CGFloat
    }

    static let paperPitch: [PaperLine] = [
        PaperLine(name: "inkHero", style: .inkHero, lineHeight: 70.4),
        PaperLine(name: "inkTitle", style: .inkTitle, lineHeight: 33),
        PaperLine(name: "inviteTitle", style: .inviteTitle, lineHeight: 33),
        PaperLine(name: "ticketTitle", style: .ticketTitle, lineHeight: 30.8),
        PaperLine(name: "inkCard", style: .inkCard, lineHeight: 24.2),
        PaperLine(name: "inkRow", style: .inkRow, lineHeight: 15.4),
    ]

    @Test("the type values are unchanged: sizes, leadings and the font's own line box")
    func existingValuesUnchanged() {
        #expect(RDimension.fontSizeHero == 64)
        #expect(RDimension.fontSize3xl == 30)
        #expect(RDimension.fontSize2xl == 28)
        #expect(RDimension.fontSizeXl == 22)
        #expect(RDimension.fontSizeMd == 14)
        let leadings: [(RTextStyle, CGFloat)] = [
            (.inkHero, 1.1), (.inkTitle, 1.1), (.inkCard, 1.1), (.displayTitle, 1.1), (.inkRow, 1.1),
            (.ticketTitle, 1.1), (.inviteTitle, 1.1), (.answerWords, 1.3), (.bodyReading, 1.45),
            (.body, 1.3), (.bodyMedium, 1.3), (.buttonLabel, 1.3), (.textMd, 1.3), (.textMdMedium, 1.3),
            (.label, 1.3), (.labelMedium, 1.3), (.metaLine, 1.3), (.pill, 1.1), (.pillAction, 1.3),
            (.tab, 1.3), (.tabSelected, 1.3), (.figure, 1.3),
        ]
        for (style, leading) in leadings {
            #expect(style.leading == leading)
        }
    }

    @Test("each ink style's line pitch equals Paper's line-height in px")
    func pitchEqualsPaper() {
        for line in Self.paperPitch {
            #expect(abs(line.style.leading * line.style.size - line.lineHeight) < 0.001, "\(line.name)")
        }
    }

    @Test("only the ink faces draw at Paper's pitch; every other face is untouched")
    func onlyInkFaces() {
        for line in Self.paperPitch {
            #expect(line.style.drawsAtPaperPitch, "\(line.name)")
        }
        // an ink face whose Paper leading is already looser than the font keeps `.lineSpacing`
        #expect(!RTextStyle.answerWords.drawsAtPaperPitch)
        for style in [RTextStyle.displayTitle, .bodyReading, .body, .textMd, .label, .metaLine, .pill, .tab, .figure] {
            #expect(!style.drawsAtPaperPitch)
        }
    }

    @Test("the cause: UIKit lays Exposure out 1.2 × size apart, 3pt a line more than Paper at 30")
    func naturalPitchIsTallerThanPaper() throws {
        let font = try #require(UIFont(name: ExposureFont.postScriptName(axis: -20, italic: false), size: RDimension.fontSize3xl))
        let natural = Self.layoutManagerPitch(font: font, paragraph: nil)
        #expect(abs(natural - 36) < 0.1)
        #expect(abs(RTextStyle.inkTitle.naturalLineHeight(scaledSize: RDimension.fontSize3xl) - natural) < 0.1)
        // the same lines with Paper's line box, as UIKit sets it
        let paper = NSMutableParagraphStyle()
        paper.minimumLineHeight = 33
        paper.maximumLineHeight = 33
        #expect(abs(Self.layoutManagerPitch(font: font, paragraph: paper) - 33) < 0.01)
    }

    @Test("a four-line ink title renders 33pt apart, line 1 in place, 135pt tall")
    func renderedPitchEqualsPaper() throws {
        let text = "H\nH\nH\nH"
        let fixed = try #require(Self.inkRows(Text(text).rText(.inkTitle)))
        let one = try #require(Self.inkRows(Text("H").rText(.inkTitle)))
        let bare = try #require(Self.inkRows(Text("H").font(RTextStyle.inkTitle.font(scaledSize: RDimension.fontSize3xl))))
        #expect(fixed.tops.count == 4)
        let pitches = zip(fixed.tops.dropFirst(), fixed.tops).map { $0 - $1 }
        for pitch in pitches {
            #expect(abs(pitch - 33) <= 0.34, "pitch \(pitch)")
        }
        // line 1 sits where SwiftUI puts a bare one-line title (where it was before the fix)
        #expect(abs(fixed.tops[0] - bare.tops[0]) <= 0.34)
        #expect(abs(one.height - bare.height) <= 0.34)
        // first line keeps the font's own 36, each later line adds one Paper pitch
        #expect(abs(fixed.height - (one.height + 3 * 33)) <= 0.67, "height \(fixed.height)")
    }

    @Test("at accessibility 3 the lines still sit leading × the scaled size apart")
    func accessibilityPitch() throws {
        let size = RTextStyle.inkTitle.scaledSize(at: .accessibility3)
        let rows = try #require(Self.inkRows(Text("H\nH\nH").rText(.inkTitle), dynamicTypeSize: .accessibility3))
        #expect(rows.tops.count == 3)
        let expected = min(RTextStyle.inkTitle.leading, RTextStyle.inkTitle.accessibilityLeading) * size
        for pitch in zip(rows.tops.dropFirst(), rows.tops).map({ $0 - $1 }) {
            #expect(abs(pitch - expected) <= 0.34, "pitch \(pitch) vs \(expected)")
        }
    }

    @Test("the height maths: one line unchanged, n lines lose (n − 1) × the squeeze")
    func heightMaths() {
        #expect(RPaperPitch.height(laidOut: 36, naturalLineHeight: 36, pitch: 33) == 36)
        #expect(RPaperPitch.height(laidOut: 144, naturalLineHeight: 36, pitch: 33) == 135)
        #expect(RPaperPitch.height(laidOut: 144, naturalLineHeight: 36, pitch: 40) == 144)
        #expect(RPaperPitch.offset(lineIndex: 3, firstBaseline: 28.5, baseline: 136.5, pitch: 33) == -9)
    }

    // MARK: - Measuring

    /// Line pitch of four lines laid out by NSLayoutManager.
    private static func layoutManagerPitch(font: UIFont, paragraph: NSParagraphStyle?) -> CGFloat {
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let paragraph {
            attributes[.paragraphStyle] = paragraph
        }
        let storage = NSTextStorage(string: "H\nH\nH\nH", attributes: attributes)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 1000, height: 1000))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        var origins: [CGFloat] = []
        manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, _, _, _, _ in
            origins.append(rect.minY)
        }
        guard origins.count > 1, let first = origins.first, let last = origins.last else { return 0 }
        return (last - first) / CGFloat(origins.count - 1)
    }

    /// Renders a view the way a screen does (a hosting controller in a window) at 3x, and returns,
    /// in points, the top of each band of ink and the view's height.
    private static func inkRows(_ view: some View, dynamicTypeSize: DynamicTypeSize = .large) -> (tops: [CGFloat], height: CGFloat)? {
        let hosting = UIHostingController(rootView: view.foregroundStyle(.black).environment(\.dynamicTypeSize, dynamicTypeSize))
        let size = hosting.sizeThatFits(in: CGSize(width: 400, height: 2000))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 2000))
        window.rootViewController = UIViewController()
        hosting.view.backgroundColor = .white
        hosting.view.frame = CGRect(origin: .zero, size: size)
        window.rootViewController?.view.addSubview(hosting.view)
        window.isHidden = false
        hosting.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            hosting.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        window.isHidden = true
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var tops: [CGFloat] = []
        var inInk = false
        for row in 0 ..< height {
            let start = row * width * 4
            // ink: a dark pixel on the white ground
            let hasInk = stride(from: start, to: start + width * 4, by: 4).contains { pixels[$0] < 128 }
            if hasInk, !inInk {
                tops.append(CGFloat(row) / 3)
            }
            inInk = hasInk
        }
        return (tops, size.height)
    }
}
