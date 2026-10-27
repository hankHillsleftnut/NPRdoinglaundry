import Foundation
import UIKit

/// Robust file-based storage system for entries
/// Stores all data in the Documents directory for persistence across app updates
class FileStorageManager {
    static let shared = FileStorageManager()

    // MARK: - Directory Structure

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var retrospectDataDirectory: URL {
        documentsDirectory.appendingPathComponent("RetrospectData", isDirectory: true)
    }

    private var entriesDirectory: URL {
        retrospectDataDirectory.appendingPathComponent("Entries", isDirectory: true)
    }

    private var videosDirectory: URL {
        retrospectDataDirectory.appendingPathComponent("Videos", isDirectory: true)
    }

    private var audiosDirectory: URL {
        retrospectDataDirectory.appendingPathComponent("Audios", isDirectory: true)
    }

    private var imagesDirectory: URL {
        retrospectDataDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    private var indexFileURL: URL {
        retrospectDataDirectory.appendingPathComponent("index.json")
    }

    // MARK: - Initialization

    private init() {
        setupDirectories()
        migrateFromUserDefaultsIfNeeded()
    }

    private func setupDirectories() {
        let directories = [retrospectDataDirectory, entriesDirectory, videosDirectory, audiosDirectory, imagesDirectory]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    print("📁 Created directory: \(directory.lastPathComponent)")
                } catch {
                    print("❌ Failed to create directory: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Entry Operations

    /// Save an entry to persistent storage
    func saveEntry(_ entry: Entry) throws {
        let entryFileURL = entriesDirectory.appendingPathComponent("\(entry.id.uuidString).json")

        // Save metadata as JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(entry)
        try jsonData.write(to: entryFileURL)

        // For text entries, also save content as a separate .txt file for easy viewing
        if entry.type == .text {
            let textFileURL = entriesDirectory.appendingPathComponent("\(entry.id.uuidString).txt")
            try entry.content.write(to: textFileURL, atomically: true, encoding: .utf8)
        }

        // For voice entries, also save transcription as a separate .txt file
        if entry.type == .voice {
            let textFileURL = entriesDirectory.appendingPathComponent("\(entry.id.uuidString)_transcript.txt")
            try entry.content.write(to: textFileURL, atomically: true, encoding: .utf8)
        }

        // Update index
        try updateIndex()

        print("💾 Saved entry: \(entry.id) (\(entry.type.rawValue))")
    }

    /// Load a specific entry by ID
    func loadEntry(id: UUID) throws -> Entry? {
        let entryFileURL = entriesDirectory.appendingPathComponent("\(id.uuidString).json")

        guard fileManager.fileExists(atPath: entryFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: entryFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(Entry.self, from: data)
    }

    /// Load all entries from storage
    func loadAllEntries() throws -> [Entry] {
        let entryFiles = try fileManager.contentsOfDirectory(
            at: entriesDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        var entries: [Entry] = []

        for fileURL in entryFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let entry = try decoder.decode(Entry.self, from: data)
                entries.append(entry)
            } catch {
                print("⚠️ Failed to load entry from \(fileURL.lastPathComponent): \(error)")
            }
        }

        print("📱 Loaded \(entries.count) entries from file storage")
        return entries.sorted(by: { $0.date > $1.date })
    }

    /// Delete an entry and its associated files
    func deleteEntry(id: UUID) throws {
        // Delete metadata JSON
        let entryFileURL = entriesDirectory.appendingPathComponent("\(id.uuidString).json")
        if fileManager.fileExists(atPath: entryFileURL.path) {
            try fileManager.removeItem(at: entryFileURL)
        }

        // Delete text file if exists
        let textFileURL = entriesDirectory.appendingPathComponent("\(id.uuidString).txt")
        if fileManager.fileExists(atPath: textFileURL.path) {
            try fileManager.removeItem(at: textFileURL)
        }

        // Delete voice transcript file if exists
        let transcriptFileURL = entriesDirectory.appendingPathComponent("\(id.uuidString)_transcript.txt")
        if fileManager.fileExists(atPath: transcriptFileURL.path) {
            try fileManager.removeItem(at: transcriptFileURL)
        }

        // Delete video file if exists
        let videoFileURL = videosDirectory.appendingPathComponent("\(id.uuidString).mov")
        if fileManager.fileExists(atPath: videoFileURL.path) {
            try fileManager.removeItem(at: videoFileURL)
        }

        // Delete audio file if exists
        let audioFileURL = audiosDirectory.appendingPathComponent("\(id.uuidString).m4a")
        if fileManager.fileExists(atPath: audioFileURL.path) {
            try fileManager.removeItem(at: audioFileURL)
        }

        // Delete associated images
        deleteImages(for: id)

        // Update index
        try updateIndex()

        print("🗑️ Deleted entry: \(id)")
    }

    // MARK: - Video Operations

    /// Get the proper path for a new video file
    func getVideoURL(for entryId: UUID) -> URL {
        return videosDirectory.appendingPathComponent("\(entryId.uuidString).mov")
    }

    /// Move a video file to the proper location
    func moveVideo(from sourceURL: URL, to entryId: UUID) throws -> URL {
        let destinationURL = getVideoURL(for: entryId)

        // If source and destination are the same, no need to move
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        // If destination exists, remove it first
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        print("📹 Moved video to: \(destinationURL.lastPathComponent)")

        return destinationURL
    }

    // MARK: - Audio Operations

    /// Get the proper path for a new audio file
    func getAudioURL(for entryId: UUID) -> URL {
        return audiosDirectory.appendingPathComponent("\(entryId.uuidString).m4a")
    }

    /// Move an audio file to the proper location
    func moveAudio(from sourceURL: URL, to entryId: UUID) throws -> URL {
        let destinationURL = getAudioURL(for: entryId)

        // If source and destination are the same, no need to move
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        // If destination exists, remove it first
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        print("🎤 Moved audio to: \(destinationURL.lastPathComponent)")

        return destinationURL
    }

    // MARK: - Image Operations

    /// Save images for an entry, compressing them to ~1MB max
    func saveImages(for entryId: UUID, images: [UIImage]) -> [URL] {
        var savedURLs: [URL] = []

        for (index, image) in images.enumerated() {
            let imageURL = imagesDirectory.appendingPathComponent("\(entryId.uuidString)_\(index).jpg")

            // Compress image to ~1MB
            if let imageData = compressImage(image, targetSizeKB: 1024) {
                do {
                    try imageData.write(to: imageURL)
                    savedURLs.append(imageURL)
                    print("🖼️ Saved image \(index + 1) for entry: \(entryId)")
                } catch {
                    print("❌ Failed to save image \(index): \(error.localizedDescription)")
                }
            }
        }

        return savedURLs
    }

    /// Load images for an entry
    func loadImages(for entryId: UUID) -> [UIImage] {
        var images: [UIImage] = []

        // Find all images for this entry
        do {
            let files = try fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            let entryImages = files.filter { $0.lastPathComponent.hasPrefix(entryId.uuidString) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            for imageURL in entryImages {
                if let imageData = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: imageData) {
                    images.append(image)
                }
            }
        } catch {
            print("❌ Failed to load images: \(error.localizedDescription)")
        }

        return images
    }

    /// Load images from URLs
    func loadImages(from urls: [URL]) -> [UIImage] {
        var images: [UIImage] = []

        for url in urls {
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                images.append(image)
            }
        }

        return images
    }

    /// Delete all images for an entry
    func deleteImages(for entryId: UUID) {
        do {
            let files = try fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            let entryImages = files.filter { $0.lastPathComponent.hasPrefix(entryId.uuidString) }

            for imageURL in entryImages {
                try fileManager.removeItem(at: imageURL)
                print("🗑️ Deleted image: \(imageURL.lastPathComponent)")
            }
        } catch {
            print("❌ Failed to delete images: \(error.localizedDescription)")
        }
    }

    /// Compress an image to approximately the target size
    private func compressImage(_ image: UIImage, targetSizeKB: Int) -> Data? {
        let targetSizeBytes = targetSizeKB * 1024
        var compression: CGFloat = 1.0
        let step: CGFloat = 0.1

        guard var imageData = image.jpegData(compressionQuality: compression) else {
            return nil
        }

        // If image is already smaller than target, return as-is
        if imageData.count <= targetSizeBytes {
            return imageData
        }

        // Reduce quality until we reach target size
        while imageData.count > targetSizeBytes, compression > step {
            compression -= step
            if let newData = image.jpegData(compressionQuality: compression) {
                imageData = newData
            }
        }

        // If still too large, resize the image
        if imageData.count > targetSizeBytes {
            let scale = sqrt(Double(targetSizeBytes) / Double(imageData.count))
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            if let resized = resizedImage,
               let resizedData = resized.jpegData(compressionQuality: 0.8) {
                return resizedData
            }
        }

        return imageData
    }

    // MARK: - Index Management

    private struct EntryIndex: Codable {
        let lastUpdated: Date
        let entryCount: Int
        let entryIds: [UUID]
    }

    private func updateIndex() throws {
        let entries = try loadAllEntries()
        let index = EntryIndex(
            lastUpdated: Date(),
            entryCount: entries.count,
            entryIds: entries.map(\.id)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        let data = try encoder.encode(index)
        try data.write(to: indexFileURL)
    }

    // MARK: - Migration from UserDefaults

    private func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "hasCompletedFileStorageMigration"

        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("✅ File storage migration already completed")
            return
        }

        print("🔄 Starting migration from UserDefaults to file storage...")

        // Migrate unified entries
        if let data = UserDefaults.standard.data(forKey: "unifiedEntries"),
           let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            print("📦 Found \(entries.count) entries to migrate")

            for entry in entries {
                do {
                    // If it's a video entry, move the video file to the new location
                    var migratedEntry = entry
                    if entry.type == .video, let oldVideoURL = entry.videoURL {
                        if fileManager.fileExists(atPath: oldVideoURL.path) {
                            let newVideoURL = try moveVideo(from: oldVideoURL, to: entry.id)
                            migratedEntry = Entry(
                                id: entry.id,
                                date: entry.date,
                                type: entry.type,
                                content: entry.content,
                                videoURL: newVideoURL,
                                audioURL: nil,
                                aiGeneratedTitle: entry.aiGeneratedTitle,
                                tags: entry.tags,
                                isIncludedInInsights: entry.isIncludedInInsights
                            )
                        }
                    } else if entry.type == .voice, let oldAudioURL = entry.audioURL, fileManager.fileExists(atPath: oldAudioURL.path) {
                        let newAudioURL = try moveAudio(from: oldAudioURL, to: entry.id)
                        migratedEntry = Entry(
                            id: entry.id,
                            date: entry.date,
                            type: entry.type,
                            content: entry.content,
                            videoURL: nil,
                            audioURL: newAudioURL,
                            aiGeneratedTitle: entry.aiGeneratedTitle,
                            tags: entry.tags,
                            isIncludedInInsights: entry.isIncludedInInsights
                        )
                    }

                    try saveEntry(migratedEntry)
                } catch {
                    print("⚠️ Failed to migrate entry \(entry.id): \(error)")
                }
            }

            print("✅ Migrated \(entries.count) entries successfully")
        }

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ File storage migration completed")
    }

    // MARK: - Debug & Export

    /// Get storage statistics
    func getStorageInfo() -> StorageInfo {
        var totalSize: Int64 = 0
        var videoCount = 0
        var voiceCount = 0
        var textCount = 0

        do {
            let entries = try loadAllEntries()

            for entry in entries {
                if entry.type == .video {
                    videoCount += 1
                    if let videoURL = entry.videoURL,
                       fileManager.fileExists(atPath: videoURL.path) {
                        let attributes = try fileManager.attributesOfItem(atPath: videoURL.path)
                        if let fileSize = attributes[.size] as? Int64 {
                            totalSize += fileSize
                        }
                    }
                } else if entry.type == .voice {
                    voiceCount += 1
                    if let audioURL = entry.audioURL,
                       fileManager.fileExists(atPath: audioURL.path) {
                        let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
                        if let fileSize = attributes[.size] as? Int64 {
                            totalSize += fileSize
                        }
                    }
                } else {
                    textCount += 1
                }
            }

            return StorageInfo(
                totalEntries: entries.count,
                videoEntries: videoCount,
                voiceEntries: voiceCount,
                textEntries: textCount,
                totalSizeBytes: totalSize,
                storageLocation: retrospectDataDirectory.path
            )
        } catch {
            print("❌ Error getting storage info: \(error)")
            return StorageInfo(
                totalEntries: 0,
                videoEntries: 0,
                voiceEntries: 0,
                textEntries: 0,
                totalSizeBytes: 0,
                storageLocation: retrospectDataDirectory.path
            )
        }
    }

    /// Export all data as a zip file (for backup)
    func getExportableDataURL() -> URL {
        return retrospectDataDirectory
    }
}

// MARK: - Storage Info Model

struct StorageInfo {
    let totalEntries: Int
    let videoEntries: Int
    let voiceEntries: Int
    let textEntries: Int
    let totalSizeBytes: Int64
    let storageLocation: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}
