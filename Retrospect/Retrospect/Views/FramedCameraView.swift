import SwiftUI
import AVFoundation

struct FramedCameraView: View {
    let session: AVCaptureSession?
    let showPlaceholder: Bool
    
    init(session: AVCaptureSession? = nil, showPlaceholder: Bool = false) {
        self.session = session
        self.showPlaceholder = showPlaceholder
    }
    
    var body: some View {
        // Outer frame
        ZStack {
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(Color(red: 0.76, green: 0.69, blue: 0.62)) // #C2B09F
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.card)
                        .stroke(Color(red: 0.75, green: 0.7, blue: 0.64), lineWidth: 2) // #BFB2A3
                )
            // Camera preview inset
            VStack {
                if let session = session, !showPlaceholder {
                    CameraPreview(session: session)
                        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.card))
                        .padding(18)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.card))
                        .padding(18)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "camera")
                                    .font(.geistDisplay).kerning(TypographyKerning.displayKerning)
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Camera Preview")
                                    .font(.geistHeadline).kerning(TypographyKerning.headlineKerning)
                                    .foregroundColor(.white.opacity(0.8))
                                if showPlaceholder {
                                    Text("Tap to start camera")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        )
                }
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
}

// MARK: - Preview
struct FramedCameraView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            FramedCameraView(showPlaceholder: true)
                .frame(width: 350, height: 262.5) // 4:3 aspect ratio
            FramedCameraView()
                .frame(width: 350, height: 262.5)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
} 