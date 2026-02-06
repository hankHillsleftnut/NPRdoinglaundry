import Foundation
import AVFoundation
import ActivityKit
import UIKit

/// Manages background audio recording without real-time transcription
/// Designed to work when app is in background or phone is locked
@MainActor
class BackgroundAudioRecordingManager: NSObject, ObservableObject {
    static let shared = BackgroundAudioRecordingManager()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    
    private var recordingStartTime: Date?
    private var timer: Timer?
    private var outputURL: URL?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Live Activity
    private var activity: Activity<VoiceRecordingAttributes>?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        // Pre-configure audio session for faster startup
        configureAudioSessionForBackground()
    }
    
    private func configureAudioSessionForBackground() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            print("✅ Audio session pre-configured for background")
        } catch {
            print("⚠️ Failed to pre-configure audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Permission Handling
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let micPermission = await requestMicrophonePermission()
            guard micPermission else {
                errorMessage = "Microphone access is required to record voice entries."
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
    
    // MARK: - Background Recording Control
    
    func startBackgroundRecording() {
        guard !isRecording else { return }
        
        // Start background task
        beginBackgroundTask()
        
        do {
            // Configure audio session for background recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
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
            
            // Install tap to capture audio buffers (for file writing only)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
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
            errorMessage = nil
            
            // Start duration timer
            startTimer()
            
            // Start Live Activity
            startLiveActivity()
            
            print("🎤 Started background recording (no real-time transcription)")
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("❌ Recording error: \(error)")
            cleanup()
            endBackgroundTask()
        }
    }
    
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
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
        
        guard let outputURL = outputURL else {
            completion(.failure(AudioRecordingError.invalidOutputURL))
            cleanup()
            endBackgroundTask()
            return
        }
        
        // Finalize asset writer
        assetWriterInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = self.assetWriter?.error {
                    print("❌ Asset writer error: \(error)")
                    completion(.failure(error))
                    self.cleanup()
                    self.endBackgroundTask()
                    return
                }
                
                // Verify file was created
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    print("✅ Background recording saved: \(outputURL.lastPathComponent)")
                    completion(.success(outputURL))
                } else {
                    print("❌ Recording file not found")
                    completion(.failure(AudioRecordingError.fileNotFound))
                }
                
                self.cleanup()
                self.endBackgroundTask()
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
        
        // Cancel asset writer
        assetWriter?.cancelWriting()
        
        // Delete temp file
        if let outputURL = outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        cleanup()
        endBackgroundTask()
        print("🚫 Background recording cancelled")
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
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            print("⚠️ Background task expired - stopping recording")
            Task { @MainActor in
                // Background time expired - save what we have
                self.stopRecording { result in
                    switch result {
                    case .success(let url):
                        print("✅ Recording saved before background expiration: \(url)")
                    case .failure(let error):
                        print("❌ Failed to save recording: \(error)")
                    }
                }
            }
        }
        print("📱 Background task started: \(backgroundTask.rawValue)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        print("📱 Background task ended")
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity() {
        guard #available(iOS 16.2, *) else {
            print("⚠️ Live Activities require iOS 16.2+")
            return
        }
        
        let authInfo = ActivityAuthorizationInfo()
        print("🔍 Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities are disabled in Settings")
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
            print("✅ Live Activity started for background recording!")
            print("📱 Activity ID: \(activity?.id ?? "none")")
        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
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
        outputURL = nil
        recordingStartTime = nil
        recordingDuration = 0
    }
}

// Note: toSampleBuffer and AudioRecordingError are defined in AudioRecordingManager.swift
// and are shared across both recording managers

