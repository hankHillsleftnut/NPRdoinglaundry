//
//  AttachmentPickerSheet.swift
//  Retrospect
//
//  Simple attachment picker with camera and photo library options
//

import SwiftUI
import PhotosUI

struct AttachmentPickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedImages: [UIImage]
    let onDeepResearch: () -> Void
    
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(LinearColors.Minimal.textTertiary)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            // Title
            Text("Add Attachment")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .padding(.bottom, 20)
            
            // Two simple buttons
            HStack(spacing: 16) {
                // Camera button
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    showCamera = true
                }) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearColors.Minimal.backgroundCard)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle()
                                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                )
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Text("Camera")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Photo Library button
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    showPhotoPicker = true
                }) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearColors.Minimal.backgroundCard)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle()
                                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                )
                            
                            Image(systemName: "photo.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                        }
                        
                        Text("Library")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 24)
            
            // Cancel button
            Button(action: {
                HapticManager.shared.playLightImpact()
                isPresented = false
            }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearColors.Minimal.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
        .sheet(isPresented: $showPhotoPicker) {
            SimplePhotoPicker(selectedImages: $selectedImages, isPresented: $isPresented)
        }
        .fullScreenCover(isPresented: $showCamera) {
            SimpleCameraView(selectedImages: $selectedImages, isPresented: $isPresented)
        }
    }
}

// MARK: - Simple Photo Picker using PHPicker
struct SimplePhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 5 - selectedImages.count
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: SimplePhotoPicker
        
        init(_ parent: SimplePhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                if self.parent.selectedImages.count < 5 {
                                    self.parent.selectedImages.append(image)
                                }
                            }
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}

// MARK: - Simple Camera View
struct SimpleCameraView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SimpleCameraView
        
        init(_ parent: SimpleCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async {
                    if self.parent.selectedImages.count < 5 {
                        self.parent.selectedImages.append(image)
                    }
                    self.parent.isPresented = false
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ZStack {
        LinearColors.Minimal.background
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            AttachmentPickerSheet(
                isPresented: .constant(true),
                selectedImages: .constant([]),
                onDeepResearch: {}
            )
        }
    }
}
