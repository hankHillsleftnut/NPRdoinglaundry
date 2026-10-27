import AVFoundation
import Foundation
import Speech

/// Service for transcribing audio files after recording completes
/// Used for background recordings where real-time transcription isn't available
@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()

    @Published var isTranscribing = false
    @Published var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Permission Handling

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let permission = await requestSpeechRecognitionPermission()
            completion(permission)
        }
    }

    private func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Transcription

    /// Transcribe an audio file (works in foreground or background)
    func transcribe(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available."
            completion(.failure(TranscriptionError.recognizerUnavailable))
            return
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file not found at \(audioURL.path)"
            completion(.failure(TranscriptionError.audioFileNotFound))
            return
        }

        isTranscribing = true
        errorMessage = nil

        print("🔄 Starting transcription for: \(audioURL.lastPathComponent)")

        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        recognitionRequest.shouldReportPartialResults = false // Only final result
        recognitionRequest.taskHint = .dictation

        speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                defer {
                    self.isTranscribing = false
                }

                if let error {
                    print("❌ Transcription error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }

                guard let result else {
                    print("❌ No transcription result")
                    self.errorMessage = "No transcription result received"
                    completion(.failure(TranscriptionError.noResult))
                    return
                }

                if result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    print("✅ Transcription completed: \(transcription.prefix(100))...")
                    print("📊 Confidence: \(result.bestTranscription.segments.map(\.confidence).reduce(0, +) / Float(result.bestTranscription.segments.count))")
                    completion(.success(transcription))
                }
            }
        }
    }

    /// Transcribe audio file with progress updates
    func transcribeWithProgress(
        audioURL: URL,
        progressHandler: @escaping (String) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available."
            completion(.failure(TranscriptionError.recognizerUnavailable))
            return
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file not found"
            completion(.failure(TranscriptionError.audioFileNotFound))
            return
        }

        isTranscribing = true
        errorMessage = nil

        print("🔄 Starting transcription with progress for: \(audioURL.lastPathComponent)")

        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        recognitionRequest.shouldReportPartialResults = true // Enable progress updates
        recognitionRequest.taskHint = .dictation

        speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let error {
                    print("❌ Transcription error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.isTranscribing = false
                    completion(.failure(error))
                    return
                }

                guard let result else {
                    print("❌ No transcription result")
                    self.errorMessage = "No transcription result received"
                    self.isTranscribing = false
                    completion(.failure(TranscriptionError.noResult))
                    return
                }

                // Send progress updates
                let currentText = result.bestTranscription.formattedString
                progressHandler(currentText)

                // Final result
                if result.isFinal {
                    print("✅ Transcription completed: \(currentText.prefix(100))...")
                    self.isTranscribing = false
                    completion(.success(currentText))
                }
            }
        }
    }

    /// Quick check if transcription is available
    func isAvailable() -> Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable
    }

    /// Get supported locales for transcription
    func supportedLocales() -> [Locale] {
        return SFSpeechRecognizer.supportedLocales().sorted { $0.identifier < $1.identifier }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case audioFileNotFound
    case noResult
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .audioFileNotFound:
            return "Audio file not found"
        case .noResult:
            return "No transcription result received"
        case .permissionDenied:
            return "Speech recognition permission denied"
        }
    }
}
