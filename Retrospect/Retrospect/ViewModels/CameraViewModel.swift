import AVFoundation
import CoreImage
import Foundation
import SwiftUI

@MainActor
class CameraViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isSessionReady = false
    @Published private(set) var isInitialized = false
    @Published private(set) var isRecording = false
    @Published var error: Error?

    // MARK: - Private Properties

    var captureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private let sessionQueue = DispatchQueue(label: "com.retrospect.camera.session")

    // MARK: - Public Properties

    var session: AVCaptureSession? {
        captureSession
    }

    // MARK: - Initialization

    init() {
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        movieFileOutput = AVCaptureMovieFileOutput()
        isInitialized = true
    }

    // MARK: - Camera Setup

    func setupCamera() async throws {
        print("🎥 CameraViewModel: Starting camera setup...")
        guard let captureSession else {
            print("❌ CameraViewModel: Capture session not initialized")
            throw CameraError.sessionNotInitialized
        }

        // Configure on background queue
        try await Task.detached {
            // First stop the session if it's running
            if captureSession.isRunning {
                captureSession.stopRunning()
            }

            // Begin configuration
            captureSession.beginConfiguration()

            // Remove any existing inputs/outputs
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.outputs.forEach { captureSession.removeOutput($0) }

            // Setup video input with ultra wide camera
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
                mediaType: .video,
                position: .front
            )

            guard let videoDevice = discoverySession.devices.first else {
                print("❌ CameraViewModel: No camera devices found")
                throw CameraError.cameraUnavailable
            }
            print("✅ CameraViewModel: Found camera device: \(videoDevice.localizedName)")

            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard captureSession.canAddInput(videoInput) else {
                throw CameraError.invalidVideoInput
            }
            captureSession.addInput(videoInput)

            // Setup audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }

            // Setup movie file output
            if let movieFileOutput = await self.movieFileOutput,
               captureSession.canAddOutput(movieFileOutput) {
                captureSession.addOutput(movieFileOutput)

                // Configure video orientation and stabilization
                if let connection = movieFileOutput.connection(with: .video) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                    connection.videoRotationAngle = 0 // 0 degrees for portrait
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                }
            }

            // Commit configuration before starting the session
            captureSession.commitConfiguration()

            // Now start the session
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }

        await MainActor.run {
            isSessionReady = true
            print("✅ CameraViewModel: Camera setup complete, session ready")
        }
    }

    // MARK: - Recording Delegate

    private class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        private let didStart: (AVCaptureConnection) -> Void
        private let didFinish: (Result<URL, Error>) -> Void

        init(
            didStart: @escaping (AVCaptureConnection) -> Void,
            didFinish: @escaping (Result<URL, Error>) -> Void
        ) {
            self.didStart = didStart
            self.didFinish = didFinish
            super.init()
        }

        func fileOutput(
            _ output: AVCaptureFileOutput,
            didStartRecordingTo fileURL: URL,
            from connections: [AVCaptureConnection]
        ) {
            if let connection = connections.first {
                didStart(connection)
            }
        }

        func fileOutput(
            _ output: AVCaptureFileOutput,
            didFinishRecordingTo outputFileURL: URL,
            from connections: [AVCaptureConnection],
            error: Error?
        ) {
            if let error {
                didFinish(.failure(error))
            } else {
                didFinish(.success(outputFileURL))
            }
        }
    }

    // MARK: - Private Properties

    private var currentRecordingDelegate: RecordingDelegate?

    // MARK: - Recording Management

    func startRecording(to outputURL: URL) async throws {
        guard let movieFileOutput else {
            throw CameraError.outputNotAvailable
        }

        if movieFileOutput.isRecording {
            throw CameraError.alreadyRecording
        }

        await MainActor.run {
            isRecording = true
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = RecordingDelegate(
                didStart: { [weak self] _ in
                    // Handle recording start
                    print("Started recording to: \(outputURL)")
                    continuation.resume()
                },
                didFinish: { [weak self] result in
                    guard let self else { return }

                    Task { @MainActor in
                        self.isRecording = false
                        self.currentRecordingDelegate = nil

                        switch result {
                        case let .success(url):
                            print("Successfully finished recording to: \(url)")
                            NotificationCenter.default.post(
                                name: .recordingDidFinish,
                                object: self,
                                userInfo: ["url": url]
                            )
                        case let .failure(error):
                            print("Failed to record: \(error.localizedDescription)")
                            NotificationCenter.default.post(
                                name: .recordingDidFail,
                                object: self,
                                userInfo: ["error": error]
                            )
                        }
                    }
                }
            )

            // Keep a strong reference to the delegate
            self.currentRecordingDelegate = delegate
            movieFileOutput.startRecording(to: outputURL, recordingDelegate: delegate)
        }
    }

    func stopRecording() async throws {
        guard let movieFileOutput, movieFileOutput.isRecording else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // The delegate will handle the completion
            movieFileOutput.stopRecording()
            continuation.resume()
        }
    }

    func stopCamera() {
        // Capture reference to avoid actor isolation issue
        let session = captureSession
        sessionQueue.async {
            session?.stopRunning()
            Task { @MainActor [weak self] in
                self?.isSessionReady = false
                self?.isRecording = false
            }
        }
    }
}

// MARK: - Error Types

extension CameraViewModel {
    enum CameraError: LocalizedError {
        case sessionNotInitialized
        case cameraUnavailable
        case invalidVideoInput
        case outputNotAvailable
        case alreadyRecording
        case recordingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .sessionNotInitialized:
                return "Camera session not initialized"
            case .cameraUnavailable:
                return "Camera is not available"
            case .invalidVideoInput:
                return "Invalid video input configuration"
            case .outputNotAvailable:
                return "Video output not available"
            case .alreadyRecording:
                return "Already recording video"
            case let .recordingFailed(error):
                return "Recording failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let recordingDidFinish = Notification.Name("CameraViewModel.recordingDidFinish")
    static let recordingDidFail = Notification.Name("CameraViewModel.recordingDidFail")
}
