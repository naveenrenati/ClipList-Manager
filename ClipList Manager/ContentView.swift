import SwiftUI
import SwiftData
import ServiceManagement

struct ContentView: View {
    @State private var showSettings: Bool = false
    @State private var showPinnedOnly: Bool = false
    @AppStorage("appAppearance") private var appAppearance: String = "System"
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showSettings = false
                    }
                }) {
                    Text("ClipList Manager")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(.plain)
                .help(showSettings ? "Return to Clipboard" : "")
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showPinnedOnly.toggle()
                        if showPinnedOnly { showSettings = false }
                    }
                }) {
                    Image(systemName: showPinnedOnly ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundStyle(showPinnedOnly ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Show Pinned Items")
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showSettings.toggle()
                        if showSettings { showPinnedOnly = false }
                    }
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(showSettings ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            // ── Main Content ───────────────────────────────────
            Group {
                if showSettings {
                    SettingsPane()
                        .transition(.opacity)
                } else {
                    ClipboardListView(showPinnedOnly: $showPinnedOnly)
                }
            }
        }
        .frame(width: 400, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: appAppearance) { _, newValue in
            updatemacOSAppearance(newValue)
        }
        .onAppear {
            updatemacOSAppearance(appAppearance)
        }
    }
    
    private func updatemacOSAppearance(_ appearance: String) {
        if appearance == "Light" {
            NSApp.appearance = NSAppearance(named: .aqua)
        } else if appearance == "Dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = nil // Reverts perfectly to System
        }
    }
}

// ── Clipboard List View ───────────────────────────────────────────
struct ClipboardListView: View {
    @Binding var showPinnedOnly: Bool
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var engine: ClipboardEngine
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    
    @State private var copiedItemId: UUID? = nil
    
    var filteredItems: [ClipboardItem] {
        if showPinnedOnly {
            return items.filter { $0.isPinned }
        } else {
            return items.filter { !$0.isPinned }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Clipboard is empty.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredItems) { item in
                                VStack(spacing: 0) {
                                    HStack(alignment: .center) {
                                        Button(action: { copyToClipboard(item) }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(item.content)
                                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                                    .lineLimit(3)
                                                    .truncationMode(.tail)
                                                    .foregroundStyle(.primary)
                                                
                                                Text(item.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        ZStack(alignment: .trailing) {
                                            if copiedItemId == item.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.green)
                                                    .transition(.scale.combined(with: .opacity))
                                                    .frame(width: 28, height: 28)
                                            } else {
                                                HStack(spacing: 8) {
                                                    Button(action: {
                                                        withAnimation { 
                                                            item.isPinned.toggle() 
                                                            if !item.isPinned {
                                                                engine.pruneHistory(context: modelContext)
                                                            }
                                                        }
                                                    }) {
                                                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                                            .font(.system(size: 14))
                                                            .foregroundStyle(item.isPinned ? Color.accentColor : .secondary.opacity(0.5))
                                                            .frame(width: 28, height: 28)
                                                    }
                                                    .buttonStyle(.plain)
                                                    
                                                    Button(action: {
                                                        withAnimation { modelContext.delete(item) }
                                                    }) {
                                                        Image(systemName: "trash")
                                                            .font(.system(size: 14))
                                                            .foregroundStyle(.secondary.opacity(0.5))
                                                            .frame(width: 28, height: 28)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        .frame(width: 64, height: 28, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 8)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            withAnimation { modelContext.delete(item) }
                                        }
                                    }
                                }
                                .padding(.vertical, 4) // Spacing between cards
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .onChange(of: filteredItems.first?.id) { _, newId in
                        if let id = newId {
                            withAnimation { proxy.scrollTo(id, anchor: .top) }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                        if let id = filteredItems.first?.id {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
        }
    }
    
    private func copyToClipboard(_ item: ClipboardItem) {
        engine.copyToClipboard(item.content)
        withAnimation(.spring) { copiedItemId = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring) {
                if copiedItemId == item.id { copiedItemId = nil }
            }
        }
    }
}



