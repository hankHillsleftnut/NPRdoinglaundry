import SwiftUI

struct StorageInfoView: View {
    @State private var storageInfo: StorageInfo?
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(LinearColors.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Storage")
                                .font(.geistTitle)
                                .kerning(TypographyKerning.titleKerning)
                                .foregroundColor(LinearColors.textPrimary)
                            
                            Text("Your data is safely stored on your device")
                                .font(.serifBody)
                                .foregroundColor(LinearColors.textSecondary)
                        }
                    }
                }
                .padding(.top, 8)
                
                // Storage Stats
                if let info = storageInfo {
                    VStack(spacing: 16) {
                        // Total Entries Card
                        StorageStatCard(
                            icon: "doc.text.fill",
                            title: "Total Entries",
                            value: "\(info.totalEntries)",
                            subtitle: "\(info.textEntries) text • \(info.videoEntries) video • \(info.voiceEntries) voice",
                            color: .blue
                        )
                        
                        // Storage Size Card
                        StorageStatCard(
                            icon: "folder.fill",
                            title: "Storage Used",
                            value: info.formattedSize,
                            subtitle: "On device",
                            color: .purple
                        )
                        
                        // Location Card
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Storage Location")
                                    .font(.geistHeadline)
                                    .foregroundColor(LinearColors.textPrimary)
                            } icon: {
                                Image(systemName: "location.fill")
                                    .foregroundColor(LinearColors.accent)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Files are stored in:")
                                    .font(.serifLabel)
                                    .foregroundColor(LinearColors.textSecondary)
                                
                                Text(info.storageLocation)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(LinearColors.textTertiary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(LinearColors.textPrimary.opacity(0.05))
                                    )
                            }
                        }
                        .coStarCard()
                    }
                }
                
                // Data Persistence Info
                InfoSection(
                    title: "How Your Data is Stored",
                    icon: "shield.checkered",
                    items: [
                        InfoItem(
                            icon: "doc.text.fill",
                            title: "Text Entries",
                            description: "Saved as .txt and .json files"
                        ),
                        InfoItem(
                            icon: "video.fill",
                            title: "Video Journals",
                            description: "Stored as .mov files with transcriptions"
                        ),
                        InfoItem(
                            icon: "waveform",
                            title: "Voice Recordings",
                            description: "Saved as .m4a files with transcriptions"
                        ),
                        InfoItem(
                            icon: "icloud.fill",
                            title: "Automatic Backup",
                            description: "Backed up to iCloud if enabled in Settings"
                        ),
                        InfoItem(
                            icon: "arrow.clockwise",
                            title: "Persistent Storage",
                            description: "Data survives app updates and rebuilds"
                        )
                    ]
                )
                
                // Export Option
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Export All Data")
                            .font(.geistHeadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: BorderRadius.button)
                            .fill(LinearColors.accent)
                    )
                    .foregroundColor(LinearColors.Minimal.textPrimary)
                }
                .padding(.top, 8)
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(LinearColors.backgroundGrey.ignoresSafeArea())
        .onAppear {
            loadStorageInfo()
        }
        .sheet(isPresented: $showShareSheet) {
            if let info = storageInfo {
                ShareSheet(activityItems: [URL(string: info.storageLocation)!])
            }
        }
    }
    
    private func loadStorageInfo() {
        storageInfo = EntryManager.shared.getStorageInfo()
    }
}

// MARK: - Storage Stat Card
struct StorageStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.serifLabel)
                    .foregroundColor(LinearColors.textSecondary)
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(LinearColors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(LinearColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(20)
        .coStarCard()
    }
}

// MARK: - Info Section
struct InfoSection: View {
    let title: String
    let icon: String
    let items: [InfoItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.geistHeadline)
                    .foregroundColor(LinearColors.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(LinearColors.accent)
            }
            
            VStack(spacing: 12) {
                ForEach(items, id: \.title) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LinearColors.accent)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.geistBody)
                                .foregroundColor(LinearColors.textPrimary)
                            
                            Text(item.description)
                                .font(.serifLabel)
                                .foregroundColor(LinearColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .coStarCard()
    }
}

struct InfoItem {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    StorageInfoView()
}

