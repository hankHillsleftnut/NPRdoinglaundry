import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Voice Recording"

    static var description: IntentDescription? = IntentDescription(
        "Stop the active voice recording",
        categoryName: "Journal"
    )

    /// Don't open app - stop in background
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        print("🛑 Stop recording triggered from Live Activity")

        // Stop recording in background
        let recorder = BackgroundAudioRecordingManager.shared
        recorder.stopRecording { result in
            switch result {
            case let .success(audioURL):
                print("✅ Recording stopped: \(audioURL.lastPathComponent)")

                // Transcribe and save
                let transcriptionService = TranscriptionService.shared
                transcriptionService.transcribe(audioURL: audioURL) { transcriptionResult in
                    switch transcriptionResult {
                    case let .success(transcription):
                        print("✅ Transcription completed")
                        Task { @MainActor in
                            await saveVoiceEntry(audioURL: audioURL, transcription: transcription)
                        }
                    case .failure:
                        print("⚠️ Transcription failed, saving without text")
                        Task { @MainActor in
                            await saveVoiceEntry(audioURL: audioURL, transcription: "")
                        }
                    }
                }

            case let .failure(error):
                print("❌ Failed to stop recording: \(error.localizedDescription)")
            }
        }

        return .result()
    }

    /// Helper to save entry
    @MainActor
    private func saveVoiceEntry(audioURL: URL, transcription: String) async {
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        let audioFileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        let hasUsableAudio = FileManager.default.fileExists(atPath: audioURL.path) && audioFileSize > 1000

        guard !trimmed.isEmpty || hasUsableAudio else {
            print("⚠️ Discarding empty voice recording from Live Activity — no content")
            return
        }

        // Generate simple title
        var title = "Voice Entry"
        if !trimmed.isEmpty {
            let words = trimmed.split(separator: " ").prefix(10)
            title = words.joined(separator: " ")
            if trimmed.split(separator: " ").count > 10 {
                title += "..."
            }
        }

        // Move audio to permanent storage
        let entryId = UUID()
        do {
            try FileStorageManager.shared.moveAudio(from: audioURL, to: entryId)

            let entry = Entry(
                id: entryId,
                type: .voice,
                content: trimmed,
                audioURL: FileStorageManager.shared.getAudioURL(for: entryId),
                aiGeneratedTitle: title,
                tags: []
            )

            EntryManager.shared.addEntry(entry)
            print("✅ Voice entry saved from Live Activity stop")
        } catch {
            print("❌ Failed to save entry: \(error.localizedDescription)")
        }
    }
}
