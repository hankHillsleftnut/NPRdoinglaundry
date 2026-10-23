import AVFoundation
import Foundation
@testable import Retrospect
import Testing

@MainActor
@Suite(.timeLimit(.minutes(3)))
struct RealEnginePlaybackTests {
    func wav() throws -> URL {
        let rate = 8000, n = rate * 3 // long enough that a slow runner cannot skip the playing window between polls
        var d = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: Int) { var x = UInt16(v).littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!); u32(36 + n * 2); d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(n * 2)
        d.append(Data(count: n * 2))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qa-\(UUID().uuidString).wav")
        try d.write(to: url)
        return url
    }

    func wait(_ p: Platform.Media.LivePlayback, _ want: Flows.PlaybackState, secs: Double = 30) async -> Bool {
        let end = Date().addingTimeInterval(secs)
        while Date() < end {
            if p.state == want {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    @Test("the real engine plays to the end, replay from ended plays again, unload silences")
    func replay() async throws {
        let url = try wav()
        let p = Platform.Media.LivePlayback(
            engine: Platform.Media.AVPlayerEngine(),
            session: Platform.Media.SystemAudioSession(),
            resolve: { _, _ in url },
            log: Platform.Log.Recorder()
        )
        let item = Flows.PlaybackItem(id: "x", kind: .brief, title: "t", parts: [], durationSeconds: 3)
        await p.load(item)
        p.play()
        let played = await wait(p, .playing)
        let ended = await wait(p, .ended)
        p.play()
        let again = await wait(p, .playing)
        let ended2 = await wait(p, .ended)
        p.unload()
        #expect(played, "plays")
        #expect(ended, "reaches the end")
        #expect(again, "replay from the end plays again")
        #expect(ended2, "and reaches the end again")
    }
}
