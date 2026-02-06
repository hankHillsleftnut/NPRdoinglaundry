import SwiftUI
import AVFoundation

struct CameraPreviewViewRepresentable: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            setupLayer(session: session)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupLayer(session: AVCaptureSession) {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
            previewLayer.connection?.isVideoMirrored = true
            
            // Set initial orientation
            updateOrientation()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
        
        func updateOrientation() {
            guard let connection = previewLayer.connection else { return }
            
            let currentInterfaceOrientation = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.interfaceOrientation ?? .portrait
            
            let videoOrientation: AVCaptureVideoOrientation
            switch currentInterfaceOrientation {
            case .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeRight
            case .landscapeRight:
                videoOrientation = .landscapeLeft
            default:
                videoOrientation = .portrait
            }
            
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView(session: session)
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.updateOrientation()
    }
}

// Wrapper to observe orientation changes from CameraManager or similar
// For now, this is a placeholder. A more robust solution would involve CameraManager publishing orientation.
// Or, we can directly use NotificationCenter to observe UIDevice.orientationDidChangeNotification.
// For simplicity, let's rely on updateUIView being called frequently enough,
// or consider adding a direct observation mechanism if orientation updates are laggy.

// Let's create a simple ObservableObject that can be used to trigger updates if needed,
// although UIInterfaceOrientation should trigger updateUIView.
// We will actually use a simpler approach by not using CameraManagerWrapper for now
// and relying on updateUIView calls due to UIInterfaceOrientation changes.
// The CameraManager already handles orientation for the *saved video file* and *CGImage stream*.
// The AVCaptureVideoPreviewLayer also has some automatic handling based on device orientation
// if its connection's `automaticallyAdjustsVideoMirroring` and `videoOrientation` are set correctly.
// The `CameraManager` already mirrors the front camera for its outputs.
// The preview layer, when connected to a front camera session, often mirrors by default.

// Let's simplify. The preview layer should mostly handle orientation if the session is configured.
// We'll ensure mirroring is explicitly set for the front camera.

// Revised CameraPreviewViewRepresentable without CameraManagerWrapper:
// The orientation logic inside the Representable itself using UIWindowScene.interfaceOrientation
// should be sufficient for the preview layer's orientation. Mirroring is also handled. 