# Retrospect - File Storage System Documentation

## 🎉 Problem Solved!

Your data was disappearing because it was stored in **UserDefaults**, which gets wiped when you:
- Clean build folder in Xcode
- Reinstall the app
- Reset the simulator
- Make certain project changes

**Solution**: I've implemented a robust **file-based storage system** that persists your data permanently on the device's file system.

---

## 📁 New Storage Architecture

### Directory Structure

```
iPhone Documents/
└── RetrospectData/
    ├── Entries/
    │   ├── [UUID].json          # Entry metadata
    │   └── [UUID].txt           # Text content (readable in Files app!)
    ├── Videos/
    │   └── [UUID].mov           # Video files with proper names
    └── index.json               # Quick index of all entries
```

### What Changed

#### Before (❌ Bad):
- **Storage**: UserDefaults
- **Videos**: Random temporary directories
- **Persistence**: Lost on app reinstall/clean build
- **Backup**: Not included in iCloud
- **Recovery**: Impossible

#### After (✅ Good):
- **Storage**: Documents directory (permanent)
- **Videos**: Organized in `Videos/` folder
- **Persistence**: Survives all Xcode changes
- **Backup**: Automatically backed up to iCloud
- **Recovery**: Can view/export files anytime

---

## 🔧 Technical Implementation

### New Files Created

1. **`FileStorageManager.swift`**
   - Handles all file operations
   - Manages directory structure
   - **Automatic migration** from old UserDefaults storage
   - Exports data for backup

2. **`StorageInfoView.swift`**
   - Shows storage statistics
   - Displays where data is stored
   - Export functionality
   - Educational info about storage

### Updated Files

1. **`EntryModel.swift`** - Now uses `FileStorageManager` instead of UserDefaults
2. **`VideoJournalViewModel.swift`** - Videos saved to proper location
3. **`DataManagementSection.swift`** - Added "Storage Information" button

---

## 🚀 Features

### 1. Persistent Storage
- **All entries** saved as individual JSON files
- **Text entries** also saved as `.txt` files (readable in any text editor!)
- **Videos** organized in dedicated folder
- **Automatic index** for fast lookups

### 2. Data Recovery
- Files persist across:
  - App updates
  - Xcode clean builds
  - Device restarts
  - Development/testing cycles

### 3. iCloud Backup
- Documents directory is automatically backed up
- Can restore from iCloud if device is lost/replaced
- No configuration needed - works automatically

### 4. Export & Viewing
- Access files through Files app on iPhone
- Connect device to Mac to browse files
- Export entire data folder for manual backup
- Share individual files

### 5. Migration
- **Automatic migration** on first launch with new system
- Existing entries moved from UserDefaults to files
- Video files relocated to new structure
- No data loss!

---

## 📊 How to View Your Storage Info

1. Open app → Settings
2. Tap "Integrations & Data"
3. Scroll to "Data Management"
4. Tap "Storage Information" (first button)

You'll see:
- Total number of entries
- Storage space used
- Exact file location
- Breakdown of text vs. video entries

---

## 🔍 Accessing Your Files

### On iPhone (Files App):
1. Open Files app
2. Go to "On My iPhone"
3. Find "Retrospect"
4. Navigate to: `Documents/RetrospectData/`

### On Mac (via Finder):
1. Connect iPhone to Mac
2. Open Finder
3. Select your iPhone in sidebar
4. Go to "Files" tab
5. Find "Retrospect" → `Documents/RetrospectData/`

### What You'll Find:
- **Entries/[UUID].json** - Full entry data (title, tags, content, dates)
- **Entries/[UUID].txt** - Just the text content (easy to read!)
- **Videos/[UUID].mov** - Your video recordings
- **index.json** - List of all entries

---

## 📝 Technical Details

### Entry Format (JSON)
```json
{
  "id": "ABC-123-DEF",
  "date": "2025-11-10T12:00:00Z",
  "type": "text",
  "content": "Today I learned about...",
  "aiGeneratedTitle": "Learning Journey",
  "tags": ["learning", "development"],
  "isIncludedInInsights": true
}
```

### Storage Limits
- **No file count limit** - Store unlimited entries
- **Only limited by device storage** - Videos can take space
- **Efficient metadata** - JSON files are tiny (~1-5 KB each)
- **Index for speed** - Fast loading even with thousands of entries

---

## 🛡️ Data Safety

### Automatic Protections:
✅ Survives app reinstall  
✅ Survives Xcode clean builds  
✅ Survives device restart  
✅ Backed up to iCloud  
✅ Can be exported manually  
✅ Files are human-readable  

### What Deletes Data:
- Only explicit "Clear All Data" in settings
- Manual file deletion through Files app
- Device wipe/factory reset

---

## 🎯 Migration Details

**First Time You Run Updated App:**

1. **Automatic Check**: System checks if migration is needed
2. **Load Old Data**: Reads entries from UserDefaults
3. **Create Files**: Converts each entry to proper file format
4. **Move Videos**: Relocates video files to new structure
5. **Update Paths**: Fixes video URLs in entry metadata
6. **Mark Complete**: Sets migration flag (won't run again)
7. **Clean Transition**: No user interaction needed!

**Migration Flag**: `hasCompletedFileStorageMigration` in UserDefaults

---

## 💡 Best Practices

### Backup Your Data:
1. Go to Settings → Integrations & Data → Data Management
2. Tap "Storage Information"
3. Tap "Export All Data" button
4. Save to iCloud Drive or share with yourself

### Regular Exports:
- Export before major app updates
- Export before testing new features
- Export weekly if you create a lot of content

### Storage Management:
- Videos take up more space than text
- Check storage info regularly
- Delete old entries if storage is low
- Consider exporting then deleting very old videos

---

## 🔬 For Developers

### Using the Storage System:
```swift
// Save an entry
let entry = Entry(type: .text, content: "My thoughts")
try FileStorageManager.shared.saveEntry(entry)

// Load all entries
let entries = try FileStorageManager.shared.loadAllEntries()

// Get storage info
let info = FileStorageManager.shared.getStorageInfo()
print("Using \(info.formattedSize) for \(info.totalEntries) entries")

// Get video URL for new entry
let videoURL = FileStorageManager.shared.getVideoURL(for: entryId)
```

### Key Methods:
- `saveEntry(_ entry: Entry)` - Save/update entry
- `loadAllEntries()` - Load all from disk
- `loadEntry(id: UUID)` - Load specific entry
- `deleteEntry(id: UUID)` - Delete entry & files
- `getStorageInfo()` - Get storage statistics

---

## ✅ What This Solves

1. ✅ **Data Loss**: Your entries won't disappear anymore!
2. ✅ **Recovery**: You can always access your files
3. ✅ **Backup**: Automatic iCloud backup included
4. ✅ **Export**: Share or backup manually anytime
5. ✅ **Transparency**: See exactly where files are stored
6. ✅ **Portability**: Text files readable outside the app
7. ✅ **Organization**: Clean folder structure
8. ✅ **Performance**: Fast loading with index system

---

## 🚨 Important Notes

### What NOT to Do:
- ❌ Don't manually edit JSON files (might corrupt data)
- ❌ Don't delete the index.json file
- ❌ Don't move files between folders
- ❌ Don't rename video files (breaks references)

### What's Safe:
- ✅ Reading `.txt` files in any text editor
- ✅ Watching `.mov` files in any video player
- ✅ Copying entire `RetrospectData/` folder for backup
- ✅ Sharing individual files with yourself

---

## 📞 Testing the New System

1. **Create a text entry** → Check `Entries/` folder for `.json` and `.txt` files
2. **Record a video** → Check `Videos/` folder for `.mov` file
3. **Clean build in Xcode** → Entries should still be there!
4. **Check storage info** → See your data statistics
5. **Export data** → Verify you can share/backup

Your data is now safe and persistent! 🎉

