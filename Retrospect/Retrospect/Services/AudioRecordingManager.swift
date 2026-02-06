import Foundation
import AVFoundation
import Speech
import ActivityKit

/// Manages audio recording with simultaneous transcription
/// Records to .m4a format while providing real-time speech-to-text
@MainActor
class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentTranscription = ""
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var recordingStartTime: Date?
    private var timer: Timer?
    private var outputURL: URL?
    
    // Live Activity
    private var activity: Activity<VoiceRecordingAttributes>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // MARK: - Permission Handling
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            // Request microphone permission
            let micPermission = await requestMicrophonePermission()
            guard micPermission else {
                errorMessage = "Microphone access is required to record voice entries."
                completion(false)
                return
            }
            
            // Request speech recognition permission
            let speechPermission = await requestSpeechRecognitionPermission()
            guard speechPermission else {
                errorMessage = "Speech recognition access is required for transcription."
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        guard !isRecording else { return }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available."
            return
        }
        
        do {
            // Setup audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Generate output URL
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "\(UUID().uuidString).m4a"
            outputURL = tempDir.appendingPathComponent(filename)
            
            guard let outputURL = outputURL else {
                throw AudioRecordingError.invalidOutputURL
            }
            
            // Setup AVAssetWriter for .m4a recording
            assetWriter = try AVAssetWriter(url: outputURL, fileType: .m4a)
            
            // Configure audio settings for .m4a
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]
            
            assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            if let assetWriter = assetWriter, let assetWriterInput = assetWriterInput {
                if assetWriter.canAdd(assetWriterInput) {
                    assetWriter.add(assetWriterInput)
                }
            }
            
            // Setup audio engine
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                throw AudioRecordingError.audioEngineFailure
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            guard recordingFormat.sampleRate > 0 else {
                throw AudioRecordingError.invalidAudioFormat
            }
            
            // Setup speech recognition
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                throw AudioRecordingError.recognitionRequestFailure
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let result = result {
                        self.currentTranscription = result.bestTranscription.formattedString
                    }
                    
                    if let error = error {
                        print("⚠️ Recognition error: \(error.localizedDescription)")
                        // Don't stop recording on transcription errors
                    }
                }
            }
            
            // Install tap to capture audio buffers
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
                // Send buffer to speech recognizer
                self.recognitionRequest?.append(buffer)
                
                // Write buffer to file
                Task { @MainActor in
                    self.writeAudioBuffer(buffer, at: time)
                }
            }
            
            // Start asset writer
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            
            // Start audio engine
            try audioEngine.start()
            
            // Update state
            isRecording = true
            recordingStartTime = Date()
            currentTranscription = ""
            errorMessage = nil
            
            // Start duration timer
            startTimer()
            
            // Start Live Activity
            startLiveActivity()
            
            print("🎤 Started recording audio")
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("❌ Recording error: \(error)")
            cleanup()
        }
    }
    
    func stopRecording(completion: @escaping (Result<(URL, String), Error>) -> Void) {
        guard isRecording else {
            completion(.failure(AudioRecordingError.notRecording))
            return
        }
        
        isRecording = false
        stopTimer()
        
        // Stop Live Activity
        stopLiveActivity()
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Stop speech recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Finalize asset writer
        assetWriterInput?.markAsFinished()
        
        let finalTranscription = currentTranscription
        guard let outputURL = outputURL else {
            completion(.failure(AudioRecordingError.invalidOutputURL))
            cleanup()
            return
        }
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = self.assetWriter?.error {
                    print("❌ Asset writer error: \(error)")
                    completion(.failure(error))
                    self.cleanup()
                    return
                }
                
                // Verify file was created
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    print("✅ Recording saved: \(outputURL.lastPathComponent)")
                    print("📝 Transcription: \(finalTranscription)")
                    completion(.success((outputURL, finalTranscription)))
                } else {
                    print("❌ Recording file not found")
                    completion(.failure(AudioRecordingError.fileNotFound))
                }
                
                self.cleanup()
            }
        }
    }
    
    func cancelRecording() {
        guard isRecording else { return }
        
        isRecording = false
        stopTimer()
        
        // Stop Live Activity
        stopLiveActivity()
        
        // Stop everything
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        assetWriterInput?.markAsFinished()
        assetWriter?.cancelWriting()
        
        // Delete temporary file
        if let outputURL = outputURL, FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        cleanup()
        print("🚫 Recording cancelled")
    }
    
    // MARK: - Private Methods
    
    private func writeAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let assetWriterInput = assetWriterInput, assetWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        // Convert AVAudioPCMBuffer to CMSampleBuffer
        guard let sampleBuffer = buffer.toSampleBuffer(at: time) else {
            return
        }
        
        assetWriterInput.append(sampleBuffer)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
                self.updateLiveActivity()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity() {
        guard #available(iOS 16.2, *) else {
            print("⚠️ Live Activities require iOS 16.2+")
            return
        }
        
        let authInfo = ActivityAuthorizationInfo()
        print("🔍 Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        print("🔍 Frequent pushes enabled: \(authInfo.frequentPushesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities are disabled in Settings")
            print("💡 Enable: Settings → Face ID & Passcode → Allow when locked: Live Activities")
            return
        }
        
        let attributes = VoiceRecordingAttributes(startTime: Date())
        let initialState = VoiceRecordingAttributes.ContentState(
            recordingDuration: 0,
            isRecording: true
        )
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            print("✅ Live Activity started successfully!")
            print("📱 Activity ID: \(activity?.id ?? "none")")
        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
        }
    }
    
    private func updateLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = activity else { return }
        
        let updatedState = VoiceRecordingAttributes.ContentState(
            recordingDuration: recordingDuration,
            isRecording: isRecording
        )
        
        Task {
            await activity.update(
                .init(state: updatedState, staleDate: nil)
            )
        }
    }
    
    private func stopLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = activity else { return }
        
        let finalState = VoiceRecordingAttributes.ContentState(
            recordingDuration: recordingDuration,
            isRecording: false
        )
        
        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            self.activity = nil
            print("✅ Live Activity stopped")
        }
    }
    
    private func cleanup() {
        audioEngine = nil
        assetWriter = nil
        assetWriterInput = nil
        recognitionRequest = nil
        recognitionTask = nil
        outputURL = nil
        recordingStartTime = nil
        recordingDuration = 0
        currentTranscription = ""
    }
}

// MARK: - Audio Buffer Extension

extension AVAudioPCMBuffer {
    func toSampleBuffer(at time: AVAudioTime) -> CMSampleBuffer? {
        var asbd = self.format.streamDescription.pointee
        
        var format: CMFormatDescription?
        var status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        )
        
        guard status == noErr, let format = format else {
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer?
        
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(asbd.mSampleRate)),
            presentationTimeStamp: CMTime(value: time.sampleTime, timescale: Int32(asbd.mSampleRate)),
            decodeTimeStamp: .invalid
        )
        
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: Int(self.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status == noErr, let buffer = sampleBuffer else {
            return nil
        }
        
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            buffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: self.audioBufferList
        )
        
        return status == noErr ? buffer : nil
    }
}

// MARK: - Errors

enum AudioRecordingError: LocalizedError {
    case invalidOutputURL
    case audioEngineFailure
    case invalidAudioFormat
    case recognitionRequestFailure
    case notRecording
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidOutputURL:
            return "Could not create output file location"
        case .audioEngineFailure:
            return "Audio engine failed to initialize"
        case .invalidAudioFormat:
            return "Invalid audio format detected"
        case .recognitionRequestFailure:
            return "Could not create speech recognition request"
        case .notRecording:
            return "Not currently recording"
        case .fileNotFound:
            return "Recording file was not created"
        }
    }
}

