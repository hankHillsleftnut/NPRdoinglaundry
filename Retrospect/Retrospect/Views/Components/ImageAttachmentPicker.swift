//
//  ImageAttachmentPicker.swift
//  Retrospect
//
//  Image attachment picker using PHPicker for photo library access
//

import SwiftUI
import PhotosUI

struct ImageAttachmentPicker: View {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    
    let maxImages: Int
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showSourcePicker = false
    
    init(selectedImages: Binding<[UIImage]>, isPresented: Binding<Bool>, maxImages: Int = 5) {
        self._selectedImages = selectedImages
        self._isPresented = isPresented
        self.maxImages = maxImages
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                Text("Add Images")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                    .padding(.top, 24)
                
                Text("Attach up to \(maxImages) images to your entry")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
                
                // Source options
                VStack(spacing: 12) {
                    // Photo Library
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: maxImages - selectedImages.count,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearColors.Minimal.accentSubtle)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.accent)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Photo Library")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                
                                Text("Choose from your photos")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.backgroundCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                )
                        )
                    }
                    .onChange(of: selectedItems) { _, newItems in
                        Task {
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    if selectedImages.count < maxImages {
                                        selectedImages.append(image)
                                    }
                                }
                            }
                            selectedItems.removeAll()
                        }
                    }
                    
                    // Camera
                    Button(action: {
                        showCamera = true
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearColors.Minimal.backgroundCardHover)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(LinearColors.Minimal.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Take Photo")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textPrimary)
                                
                                Text("Capture with your camera")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(LinearColors.Minimal.textTertiary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.backgroundCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                                )
                        )
                    }
                    .disabled(selectedImages.count >= maxImages)
                    .opacity(selectedImages.count >= maxImages ? 0.5 : 1)
                }
                .padding(.horizontal, 20)
                
                // Selected images preview
                if !selectedImages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Selected (\(selectedImages.count)/\(maxImages))")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(LinearColors.Minimal.textSecondary)
                            
                            Spacer()
                            
                            Button(action: {
                                selectedImages.removeAll()
                            }) {
                                Text("Clear All")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(LinearColors.Minimal.error)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        Button(action: {
                                            selectedImages.remove(at: index)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .frame(width: 24, height: 24)
                                                
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer()
                
                // Done button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LinearColors.Minimal.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearColors.Minimal.accent)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(LinearColors.Minimal.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: Binding(
                get: { nil },
                set: { image in
                    if let image = image, selectedImages.count < maxImages {
                        selectedImages.append(image)
                    }
                }
            ))
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
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
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ImageAttachmentPicker(
        selectedImages: .constant([]),
        isPresented: .constant(true)
    )
}

