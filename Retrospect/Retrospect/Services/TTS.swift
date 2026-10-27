import AVFoundation
import Foundation

class TextToSpeechService {
    /// Singleton pattern for consistent audio session management
    static let shared = TextToSpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()

    private init() {
        setupAudioSession()
    }

    /// Check if speech synthesis is available on this device
    func isSpeechSynthesisAvailable() -> Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return !voices.isEmpty &&
            AVSpeechSynthesisVoice(language: "en-US") != nil
    }

    /// Configure audio session for speech synthesis
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("❌ Audio Session Setup Failed: \(error.localizedDescription)")
        }
    }

    /// Comprehensive text-to-speech conversion
    func convertToSpeech(text: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Check device capabilities first
        guard isSpeechSynthesisAvailable() else {
            completion(.failure(TextToSpeechError.deviceNotSupported))
            return
        }

        // Validate input
        guard !text.isEmpty else {
            completion(.failure(TextToSpeechError.emptyText))
            return
        }

        // Create unique audio file URL
        let audioFilename = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("\(UUID().uuidString).m4a")

        // Prepare audio engine for recording
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)

        do {
            try audioEngine.start()
        } catch {
            completion(.failure(TextToSpeechError.audioEngineStartFailed))
            return
        }

        // Prepare utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 0.8

        // Prepare audio file
        guard (try? AVAudioFile(
            forWriting: audioFilename,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
        )) != nil else {
            completion(.failure(TextToSpeechError.audioFileCreationFailed))
            return
        }

        // Create a buffer to capture synthesized speech
        let bufferSize: AVAudioFrameCount = 4096
        let audioFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        guard AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bufferSize) != nil else {
            completion(.failure(TextToSpeechError.bufferCreationFailed))
            return
        }

        // Synthesize speech
        synthesizer.speak(utterance)

        // Monitor synthesis completion
        var synthesisCompleted = false

        // Use a delegate to track completion
        class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
            var completionHandler: (() -> Void)?

            func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
                completionHandler?()
            }
        }

        let delegate = SynthesizerDelegate()
        synthesizer.delegate = delegate

        delegate.completionHandler = {
            synthesisCompleted = true
            audioEngine.stop()
            completion(.success(audioFilename))
        }

        // Timeout mechanism
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard !synthesisCompleted else { return }
            audioEngine.stop()
            completion(.failure(TextToSpeechError.synthesizationFailed))
        }
    }

    /// Custom error types for precise error handling
    enum TextToSpeechError: Error {
        case emptyText
        case audioFileCreationFailed
        case audioEngineStartFailed
        case synthesizationFailed
        case bufferCreationFailed
        case deviceNotSupported
    }
}
