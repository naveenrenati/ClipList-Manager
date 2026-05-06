//
//  ClipList_ManagerApp.swift
//  ClipList Manager
//
//  Created by Naveen Renati on 19/04/26.
//
import SwiftUI
import SwiftData
import AppKit
import Carbon

@main
struct ClipList_ManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: FloatingPanel!
    var eventMonitor: Any?
    
    let engine = ClipboardEngine()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ClipboardItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Schema migration failed. Resetting database: \(error)")
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: nil)
            button.action = #selector(togglePanel(_:))
        }
        
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.backgroundColor = .clear
        
        let rootView = ContentView()
            .modelContainer(sharedModelContainer)
            .environmentObject(engine)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
        panel.contentView = NSHostingView(rootView: rootView)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceDidChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        // Start the background clipboard monitoring engine
        engine.start(context: sharedModelContainer.mainContext)
        
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel), name: NSNotification.Name("ClosePanelNotification"), object: nil)
        
        // Register Global HotKey (⌘ + Shift + V)
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.togglePanel(nil)
            if let window = self?.panel {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
        // Read stored custom shortcut or default to cmdShiftV
        if let data = UserDefaults.standard.data(forKey: "customGlobalShortcut"),
           let savedShortcut = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            HotKeyManager.shared.registerHotKey(savedShortcut)
        } else {
            HotKeyManager.shared.registerHotKey(.defaultShortcut)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !panel.isVisible { openPanel() }
        return true
    }
    
    @objc func spaceDidChange() {
        if panel.isVisible { closePanel() }
    }
    
    @objc func togglePanel(_ sender: Any?) {
        if panel.isVisible { closePanel() } else { openPanel() }
    }
    
    func openPanel() {
        guard let button = statusItem.button, let window = button.window else { return }
        
        let buttonScreenRect = window.convertToScreen(button.frame)
        let panelW: CGFloat = 400
        let panelH: CGFloat = 380
        let x = buttonScreenRect.midX - (panelW / 2)
        let y = buttonScreenRect.minY - panelH - 4 // 4 pt gap below menu bar
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }
    
    @objc func closePanel() {
        panel.orderOut(nil)
        NSApp.hide(nil) // Restores keyboard focus to the previous active app
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
}

// ── Global HotKey Manager (Carbon) ───────────────────────────────────
class HotKeyManager {
    static let shared = HotKeyManager()
    var onHotKey: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    func registerHotKey(_ shortcut: CustomShortcut) {
        // Unregister existing if any
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        
        let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode: "CLIP"), id: 1)
        
        RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let ptr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            if let userData = userData {
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onHotKey?() }
            }
            return noErr
        }, 1, &eventType, ptr, &eventHandlerRef)
    }
}

extension OSType {
    init(fourCharCode: String) {
        var result: OSType = 0
        for char in fourCharCode.utf8 {
            result = (result << 8) + OSType(char)
        }
        self = result
    }
}
