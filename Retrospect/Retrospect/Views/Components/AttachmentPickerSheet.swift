//
//  AttachmentPickerSheet.swift
//  Retrospect
//
//  Simple attachment picker with camera and photo library options
//

import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

struct AttachmentPickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedImages: [UIImage]
    let onDeepResearch: () -> Void
    
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var isImportingFiles = false
    @State private var isFileDropTargeted = false
    @State private var importStatus: String?
    
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .padding(.bottom, 20)
            
            // Attachment buttons
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
                            .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(LinearColors.Minimal.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Files button
                Button(action: {
                    HapticManager.shared.playLightImpact()
                    showFileImporter = true
                }) {
                    attachmentButton(icon: "doc.text.fill", title: "Files")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isImportingFiles)
            }
            .padding(.bottom, 16)

            VStack(spacing: 6) {
                if isImportingFiles {
                    ProgressView()
                        .tint(LinearColors.Minimal.textTertiary)
                }

                Text(importStatus ?? "Choose or drop Apple Notes PDF exports")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
            
            // Cancel button
            Button(action: {
                HapticManager.shared.playLightImpact()
                isPresented = false
            }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
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
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isFileDropTargeted ? LinearColors.Minimal.accent : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
        .onDrop(of: [UTType.pdf.identifier], isTargeted: $isFileDropTargeted) { providers in
            importDroppedPDFs(from: providers)
            return true
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                importPDFs(from: urls)
            case .failure(let error):
                importStatus = "File import failed: \(error.localizedDescription)"
                HapticManager.shared.playErrorNotification()
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            SimplePhotoPicker(selectedImages: $selectedImages, isPresented: $isPresented)
        }
        .fullScreenCover(isPresented: $showCamera) {
            SimpleCameraView(selectedImages: $selectedImages, isPresented: $isPresented)
        }
    }

    private func attachmentButton(icon: String, title: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearColors.Minimal.backgroundCard)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .strokeBorder(LinearColors.Minimal.border, lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(LinearColors.Minimal.textSecondary)
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(LinearColors.Minimal.textSecondary)
        }
    }

    private func importPDFs(from urls: [URL], cleanupAfterImport: Bool = false) {
        guard !urls.isEmpty else { return }

        isImportingFiles = true
        importStatus = "Importing \(urls.count) PDF\(urls.count == 1 ? "" : "s")..."

        Task {
            let result = await AppleNotesPDFImporter.extractNotes(from: urls)

            await MainActor.run {
                if cleanupAfterImport {
                    urls.forEach { try? FileManager.default.removeItem(at: $0) }
                }

                for note in result.notes {
                    let entry = Entry(
                        type: .text,
                        content: note.content,
                        aiGeneratedTitle: note.title,
                        tags: ["apple-notes", "pdf-import"]
                    )
                    EntryManager.shared.addEntry(entry)
                }

                isImportingFiles = false

                if result.notes.isEmpty {
                    importStatus = "No readable text found in the selected PDF\(urls.count == 1 ? "" : "s")."
                    HapticManager.shared.playErrorNotification()
                    return
                }

                let failedText = result.failedFiles.isEmpty
                    ? ""
                    : " \(result.failedFiles.count) file\(result.failedFiles.count == 1 ? "" : "s") skipped."
                importStatus = "Imported \(result.notes.count) note\(result.notes.count == 1 ? "" : "s").\(failedText)"
                HapticManager.shared.playSuccessNotification()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    isPresented = false
                }
            }
        }
    }

    private func importDroppedPDFs(from providers: [NSItemProvider]) {
        let pdfProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
        }
        guard !pdfProviders.isEmpty else {
            importStatus = "Drop Apple Notes PDF files here."
            return
        }

        isImportingFiles = true
        importStatus = "Preparing dropped PDF\(pdfProviders.count == 1 ? "" : "s")..."

        let group = DispatchGroup()
        let lock = NSLock()
        var copiedURLs: [URL] = []

        for provider in pdfProviders {
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, _ in
                defer { group.leave() }
                guard let url else { return }

                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("pdf")

                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                    lock.lock()
                    copiedURLs.append(destination)
                    lock.unlock()
                } catch {
                    print("Dropped PDF copy failed: \(error.localizedDescription)")
                }
            }
        }

        group.notify(queue: .main) {
            if copiedURLs.isEmpty {
                isImportingFiles = false
                importStatus = "Could not read the dropped PDF files."
                HapticManager.shared.playErrorNotification()
                return
            }

            importPDFs(from: copiedURLs, cleanupAfterImport: true)
        }
    }
}

private struct ImportedPDFNote {
    let title: String
    let content: String
}

private struct PDFImportResult {
    let notes: [ImportedPDFNote]
    let failedFiles: [String]
}

private enum AppleNotesPDFImporter {
    static func extractNotes(from urls: [URL]) async -> PDFImportResult {
        var notes: [ImportedPDFNote] = []
        var failedFiles: [String] = []

        for url in urls {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let document = PDFDocument(url: url) else {
                failedFiles.append(url.lastPathComponent)
                continue
            }

            let pageText = (0..<document.pageCount).compactMap { index in
                document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let content = pageText
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !content.isEmpty else {
                failedFiles.append(url.lastPathComponent)
                continue
            }

            let title = url.deletingPathExtension().lastPathComponent
            notes.append(ImportedPDFNote(title: title, content: content))
        }

        return PDFImportResult(notes: notes, failedFiles: failedFiles)
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
