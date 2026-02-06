import Foundation
import AVFoundation

class TextToSpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    
    func convertToSpeech(text: String, completion: @escaping (URL?) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            completion(nil)
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        // Prepare a temporary file path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("\(UUID().uuidString).caf")

        // Prepare an AVAudioEngine to record synthesized speech
        let engine = AVAudioEngine()
        let mixer = engine.mainMixerNode
        let outputFormat = mixer.outputFormat(forBus: 0)

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
        } catch {
            print("Failed to create audio file: \(error)")
            completion(nil)
            return
        }

        mixer.installTap(onBus: 0, bufferSize: 1024, format: outputFormat) { (buffer, _) in
            do {
                try file.write(from: buffer)
            } catch {
                print("Error writing buffer: \(error)")
            }
        }

        do {
            try engine.start()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
            completion(nil)
            return
        }

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = nil

        synthesizer.speak(utterance)

        DispatchQueue.global().async {
            while synthesizer.isSpeaking {
                usleep(100000)
            }

            mixer.removeTap(onBus: 0)
            engine.stop()

            DispatchQueue.main.async {
                completion(outputURL)
            }
        }
    }
}
