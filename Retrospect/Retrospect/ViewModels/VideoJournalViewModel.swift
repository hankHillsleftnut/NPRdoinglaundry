import AVFoundation
import Foundation
import Speech
import SwiftUI

@MainActor
final class VideoJournalViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRecording = false
    @Published private(set) var transcribedText = ""
    @Published var errorMessage: String?
    @Published var showErrorAlert = false
    @Published var isCameraAuthorized = false
    @Published var isMicrophoneAuthorized = false
    @Published var isSpeechAuthorized = false

    // MARK: - Private Properties

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentVideoURL: URL?

    /// Actor-isolated property for transcription
    private var currentTranscription = ""

    // MARK: - Session Management

    func initializeCaptureSession() async throws {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try await audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try await audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw TranscriptionError.audioSessionSetupFailed(error)
        }
    }

    // MARK: - Recording Management

    func startRecording(cameraViewModel: CameraViewModel) async throws {
        guard !isRecording else { return }

        // Create unique output file
        let outputURL = try createUniqueVideoURL()
        currentVideoURL = outputURL

        // Reset transcribed text
        transcribedText = ""
        currentTranscription = ""

        do {
            // Start camera recording
            try await cameraViewModel.startRecording(to: outputURL)

            // Start speech recognition
            try await startSpeechRecognition()

            isRecording = true
        } catch {
            throw TranscriptionError.recordingFailed(error)
        }
    }

    func stopRecording(cameraViewModel: CameraViewModel) async throws {
        guard isRecording else { return }

        // Stop camera recording
        try await cameraViewModel.stopRecording()

        // Stop speech recognition
        await stopSpeechRecognition()

        // Create journal entry if we have a video URL
        if let videoURL = currentVideoURL {
            createJournalEntry(videoURL: videoURL)
        }

        isRecording = false
    }

    // MARK: - Speech Recognition

    private func startSpeechRecognition() async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw TranscriptionError.speechRecognitionUnavailable
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest else {
            throw TranscriptionError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.currentTranscription = transcription
                    self.transcribedText = transcription
                }
            }

            if error != nil || result?.isFinal == true {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                recognitionTask = nil
            }
        }

        try audioEngine.start()
    }

    private func stopSpeechRecognition() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Helper Methods

    private func createUniqueVideoURL() throws -> URL {
        // Generate a UUID for this entry
        let entryId = UUID()
        // Use FileStorageManager to get the proper video URL
        return FileStorageManager.shared.getVideoURL(for: entryId)
    }

    private func createJournalEntry(videoURL: URL) {
        let entryDate = Date()
        let transcription = transcribedText

        // Create and save video journal entry (for backward compatibility)
        let videoEntry = VideoJournalEntry(
            date: entryDate,
            videoURL: videoURL,
            transcription: transcription,
            isIncludedInInsights: true
        )
        VideoJournalManager.shared.addEntry(videoEntry)

        // Generate metadata and create unified entry
        AIServiceManager.shared.analyzeEntryForMetadata(content: transcription) { result in
            Task { @MainActor in
                switch result {
                case let .success(metadata):
                    let unifiedEntry = Entry(
                        date: entryDate,
                        type: .video,
                        content: transcription,
                        videoURL: videoURL,
                        aiGeneratedTitle: metadata.title,
                        tags: metadata.tags,
                        isIncludedInInsights: true
                    )
                    EntryManager.shared.addEntry(unifiedEntry)
                    print("✅ Created unified video entry with metadata")

                case let .failure(error):
                    print("⚠️ Failed to generate metadata: \(error), using fallback")
                    // Create entry without AI metadata (will use date-based title)
                    let unifiedEntry = Entry(
                        date: entryDate,
                        type: .video,
                        content: transcription,
                        videoURL: videoURL,
                        aiGeneratedTitle: nil,
                        tags: [],
                        isIncludedInInsights: true
                    )
                    EntryManager.shared.addEntry(unifiedEntry)
                }
            }
        }
    }

    func cleanUp() async {
        if isRecording {
            await stopSpeechRecognition()
        }

        await MainActor.run {
            transcribedText = ""
            currentTranscription = ""
        }
    }

    // MARK: - Error Types

    enum TranscriptionError: LocalizedError {
        case audioSessionSetupFailed(Error)
        case speechRecognitionUnavailable
        case recognitionRequestFailed
        case recordingFailed(Error)

        var errorDescription: String? {
            switch self {
            case let .audioSessionSetupFailed(error):
                return "Failed to set up audio session: \(error.localizedDescription)"
            case .speechRecognitionUnavailable:
                return "Speech recognition is not available on this device"
            case .recognitionRequestFailed:
                return "Failed to create speech recognition request"
            case let .recordingFailed(error):
                return "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }

    func showError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            showErrorAlert = true
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoJournalViewModel /*: AVCaptureFileOutputRecordingDelegate */ {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            print("Error recording video: \(error)")
            Task { @MainActor in
                self.errorMessage = "Failed to save video: \(error.localizedDescription)"
                self.showErrorAlert = true
            }
            return
        }

        Task { @MainActor in
            let entry = VideoJournalEntry(
                videoURL: outputFileURL,
                transcription: transcribedText
            )

            VideoJournalManager.shared.addEntry(entry)
            print("Video journal entry saved successfully")
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Started recording video to: \(fileURL)")
    }
}
