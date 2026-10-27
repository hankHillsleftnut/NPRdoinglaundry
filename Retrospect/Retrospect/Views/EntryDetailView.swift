import AVKit
import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var entryManager = EntryManager.shared
    @State private var entry: Entry
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isEditingTags = false
    @State private var newTag = ""
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false

    init(entry: Entry) {
        _entry = State(initialValue: entry)
        _editedTitle = State(initialValue: entry.aiGeneratedTitle ?? "")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header spacing for dismiss button
                    Spacer()
                        .frame(height: 40)

                    // Title Section
                    titleSection

                    // Tags Section
                    tagsSection

                    // Content Section
                    contentSection

                    // Action Buttons
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(LinearColors.backgroundGrey.ignoresSafeArea())

            // Dismiss Button (floating)
            dismissButton
                .padding(.top, 16)
                .padding(.trailing, 20)
        }
        .alert("Delete Entry", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: {
            HapticManager.shared.playLightImpact()
            dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LinearColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(LinearColors.cardBackground)
                        .shadow(
                            color: Shadows.cardShadow.color,
                            radius: Shadows.cardShadow.radius,
                            x: Shadows.cardShadow.x,
                            y: Shadows.cardShadow.y
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Type Badge and Date
            HStack {
                typeBadge

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LinearColors.textSecondary)
            }

            // Title with Edit
            if isEditingTitle {
                VStack(spacing: 12) {
                    TextField("Entry title", text: $editedTitle)
                        .font(.serifTitle)
                        .fontWeight(.bold)
                        .foregroundColor(LinearColors.textPrimary)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.input)
                                .fill(LinearColors.inputBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BorderRadius.input)
                                        .stroke(LinearColors.inputFocusBorder, lineWidth: 1)
                                )
                        )

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            HapticManager.shared.playLightImpact()
                            editedTitle = entry.aiGeneratedTitle ?? ""
                            isEditingTitle = false
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(LinearColors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(LinearColors.cardBackground)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                                )
                        )

                        Spacer()

                        Button("Save") {
                            HapticManager.shared.playMediumImpact()
                            saveTitle()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LinearColors.Minimal.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(LinearColors.accent)
                        )
                    }
                }
            } else {
                HStack(alignment: .top) {
                    Text(entry.displayTitle)
                        .font(.serifTitle)
                        .fontWeight(.bold)
                        .foregroundColor(LinearColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Button(action: {
                        HapticManager.shared.playLightImpact()
                        isEditingTitle = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.accent)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(LinearColors.accent.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .shadow(
                    color: Shadows.cardShadow.color,
                    radius: Shadows.cardShadow.radius,
                    x: Shadows.cardShadow.x,
                    y: Shadows.cardShadow.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
        )
    }

    private var typeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: badgeIcon)
                .font(.system(size: 13, weight: .medium))
            Text(badgeText)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(badgeForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(badgeBackground)
        )
    }

    private var badgeIcon: String {
        switch entry.type {
        case .video: return "video.fill"
        case .voice: return "waveform"
        case .text: return "doc.text.fill"
        }
    }

    private var badgeText: String {
        switch entry.type {
        case .video: return "Video Entry"
        case .voice: return "Voice Entry"
        case .text: return "Text Entry"
        }
    }

    private var badgeForeground: Color {
        switch entry.type {
        case .video: return .white
        case .voice: return .white
        case .text: return LinearColors.textPrimary
        }
    }

    private var badgeBackground: Color {
        switch entry.type {
        case .video: return LinearColors.accent
        case .voice: return LinearColors.Minimal.iconPurple
        case .text: return LinearColors.cardBorder.opacity(0.5)
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TAGS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(LinearColors.textSecondary)

                Spacer()

                Button(action: {
                    HapticManager.shared.playLightImpact()
                    isEditingTags.toggle()
                }) {
                    Image(systemName: isEditingTags ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LinearColors.accent)
                }
            }

            if entry.tags.isEmpty, !isEditingTags {
                Text("No tags yet. Tap + to add some.")
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textSecondary.opacity(0.6))
                    .italic()
            } else {
                // Simple wrapping tag layout
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(stride(from: 0, to: entry.tags.count, by: 1)), id: \.self) { index in
                        if index < entry.tags.count {
                            let tag = entry.tags[index]
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(LinearColors.accent)

                                if isEditingTags {
                                    Button(action: {
                                        HapticManager.shared.playLightImpact()
                                        removeTag(tag)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(LinearColors.textSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(LinearColors.accent.opacity(0.1))
                            )
                        }
                    }
                }
            }

            if isEditingTags {
                HStack(spacing: 10) {
                    TextField("Add tag", text: $newTag)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(LinearColors.inputBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(LinearColors.inputBorder, lineWidth: 1)
                                )
                        )
                        .onSubmit {
                            addTag()
                        }

                    Button(action: {
                        HapticManager.shared.playMediumImpact()
                        addTag()
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(LinearColors.accent)
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .shadow(
                    color: Shadows.cardShadow.color,
                    radius: Shadows.cardShadow.radius,
                    x: Shadows.cardShadow.x,
                    y: Shadows.cardShadow.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CONTENT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(LinearColors.textSecondary)

            if entry.type == .video, let videoURL = entry.videoURL {
                // Video Player
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 280)
                    .cornerRadius(BorderRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.card)
                            .strokeBorder(LinearColors.cardBorder.opacity(0.5), lineWidth: 1)
                    )

                if !entry.content.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    Text("TRANSCRIPTION")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LinearColors.textSecondary)
                }
            } else if entry.type == .voice, let audioURL = entry.audioURL {
                // Audio Player
                VoiceEntryPlayerView(audioURL: audioURL)

                if !entry.content.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    Text("TRANSCRIPTION")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(LinearColors.textSecondary)
                }
            }

            // Text Content (or transcription for video/voice)
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.serifBody)
                    .foregroundColor(LinearColors.textPrimary)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .fill(LinearColors.cardBackground)
                .shadow(
                    color: Shadows.cardShadow.color,
                    radius: Shadows.cardShadow.radius,
                    x: Shadows.cardShadow.x,
                    y: Shadows.cardShadow.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.card)
                .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Share Button
            Button(action: {
                HapticManager.shared.playMediumImpact()
                showShareSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                    Text("Share")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(LinearColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.cardBackground)
                        .shadow(
                            color: Shadows.cardShadow.color,
                            radius: Shadows.cardShadow.radius,
                            x: Shadows.cardShadow.x,
                            y: Shadows.cardShadow.y
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .strokeBorder(LinearColors.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Delete Button
            Button(action: {
                HapticManager.shared.playMediumImpact()
                showDeleteAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                    Text("Delete")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(LinearColors.Minimal.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.button)
                        .fill(LinearColors.Minimal.deleteRed)
                        .shadow(
                            color: LinearColors.Minimal.deleteRed.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Helper Methods

    private func saveTitle() {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            var updatedEntry = entry
            updatedEntry.aiGeneratedTitle = trimmedTitle
            entryManager.updateEntry(updatedEntry)
            entry = updatedEntry
        }
        isEditingTitle = false
    }

    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedTag.isEmpty, !entry.tags.contains(trimmedTag) {
            var updatedEntry = entry
            updatedEntry.tags.append(trimmedTag)
            entryManager.updateEntry(updatedEntry)
            entry = updatedEntry
            newTag = ""
        }
    }

    private func removeTag(_ tag: String) {
        var updatedEntry = entry
        updatedEntry.tags.removeAll { $0 == tag }
        entryManager.updateEntry(updatedEntry)
        entry = updatedEntry
    }

    private func deleteEntry() {
        entryManager.deleteEntry(withId: entry.id)
        dismiss()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: entry.date)
    }

    private var shareText: String {
        var text = entry.displayTitle + "\n\n"
        if !entry.tags.isEmpty {
            text += "Tags: " + entry.tags.joined(separator: ", ") + "\n\n"
        }
        text += entry.content
        return text
    }
}
