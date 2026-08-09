import SwiftUI
import AppKit

@main
struct RetrospectMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store: JournalStore
    @StateObject private var session: SessionMonitor
    @StateObject private var sync: SyncEngine
    @StateObject private var api = RetrospectAPI.shared
    @StateObject private var auth = AuthManager()
    @StateObject private var editor = EditorController()

    init() {
        Typeface.register()
        let store = JournalStore()
        let session = SessionMonitor()
        let sync = SyncEngine(store: store, session: session)
        _store = StateObject(wrappedValue: store)
        _session = StateObject(wrappedValue: session)
        _sync = StateObject(wrappedValue: sync)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(session)
                .environmentObject(sync)
                .environmentObject(api)
                .environmentObject(auth)
                .environmentObject(editor)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    sync.flushNow()
                }
                .onAppear { appDelegate.sync = sync }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") { store.newEntry() }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

/// Owns the menu bar status item, the global hotkey, and termination flush.
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var sync: SyncEngine?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        GlobalHotkey.shared.register { [weak self] in self?.summon() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        sync?.flushNow()
        GlobalHotkey.shared.unregister()
    }

    /// Keep the app alive in the menu bar even if the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "Retrospect")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Retrospect", action: #selector(summon), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Retrospect", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func summon() {
        NSApp.activate(ignoringOtherApps: true)
        // Reopening a closed SwiftUI window is handled by the system on activation.
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }

    /// Re-create the main window when summoned after the last window was closed.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSApp.windows.first?.makeKeyAndOrderFront(nil) }
        return true
    }
}
