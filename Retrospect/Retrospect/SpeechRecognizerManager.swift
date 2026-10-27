import AVFoundation
import Foundation
import Speech

class SpeechRecognizerManager: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    @Published var errorMessage: String?

    override init() {
        super.init()
        speechRecognizer.delegate = self
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    completion(true)
                default:
                    self.errorMessage = "Speech recognition authorization denied or restricted."
                    completion(false)
                }
            }
        }
    }

    func startTranscribing() {
        guard speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available."
            return
        }

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup error: \(error.localizedDescription)"
            print("Audio session setup error: \(error)")
            return
        }

        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result {
                self.transcribedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Transcript: \(self.transcribedText)")
            }

            if error != nil || isFinal {
                self.stopTranscribing()
                if let error {
                    print("Recognition error: \(error.localizedDescription)")
                    if (error as NSError).code != 203 {
                        self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    }
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            errorMessage = "Input node recording format is invalid (sample rate is 0)."
            print("Input node recording format is invalid (sample rate is 0).")
            audioEngine.stop()
            self.recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionTask = nil
            self.recognitionRequest = nil
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.errorMessage = nil
            }
            print("Speech Recognizer: Audio engine started, listening...")
        } catch {
            errorMessage = "Audio engine start error: \(error.localizedDescription)"
            print("Audio engine start error: \(error)")
            stopTranscribing()
        }
    }

    func stopTranscribing() {
        DispatchQueue.main.async {
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                print("Speech Recognizer: Audio engine stopped.")
            }
            self.recognitionRequest?.endAudio()
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
            self.isListening = false
            print("Speech Recognizer: Transcription stopped.")
        }
    }
}

extension SpeechRecognizerManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognizer became unavailable."
                self.isListening = false
                self.stopTranscribing()
            }
        }
    }
}
