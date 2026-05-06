import SwiftUI
import SwiftData
import ServiceManagement

struct ContentView: View {
    @State private var showSettings: Bool = false
    @State private var showPinnedOnly: Bool = false
    @State private var searchQuery: String = ""
    @AppStorage("appAppearance") private var appAppearance: String = "System"
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showSettings = false
                    }
                }) {
                    Text("ClipList Manager")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.1, green: 0.2, blue: 0.5)) // Navy blue
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .help(showSettings ? "Return to Clipboard" : "")
                
                // ── Search Field ───────────────────────────────
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Search or type / to filter...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .id("searchField")
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(maxWidth: .infinity)
                
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
                        if showSettings { showPinnedOnly = false; searchQuery = "" }
                    }
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(showSettings ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            // ── Main Content ───────────────────────────────────
            Group {
                if showSettings {
                    SettingsPane()
                        .transition(.opacity)
                } else {
                    ClipboardListView(showPinnedOnly: $showPinnedOnly, searchQuery: $searchQuery)
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
    @Binding var searchQuery: String
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var engine: ClipboardEngine
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    
    @State private var copiedItemId: UUID? = nil
    @State private var selectedIndex: Int = 0
    
    var filteredItems: [ClipboardItem] {
        let base = showPinnedOnly ? items.filter { $0.isPinned } : items.filter { !$0.isPinned }
        guard !searchQuery.isEmpty else { return base }
        
        if searchQuery.hasPrefix("/") {
            let filterTerm = searchQuery.dropFirst().lowercased()
            guard !filterTerm.isEmpty else { return base }
            
            // Find ALL matching content types (e.g., "/co" -> matches "Color" and "Code")
            let matchedTypes = ClipboardContentType.allCases.filter { $0.label.lowercased().hasPrefix(filterTerm) }
            
            if !matchedTypes.isEmpty {
                return base.filter { item in 
                    matchedTypes.contains(ClipboardContentType.detect(item.content))
                }
            } else {
                return [] // No matching type found
            }
        }
        
        return base.filter { $0.content.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchQuery.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty ? "Clipboard is empty." : "No results for \"\(searchQuery)\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                VStack(spacing: 0) {
                                    HStack(alignment: .center) {
                                        Button(action: { copyToClipboard(item, autoClose: false) }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(item.content)
                                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                                    .lineLimit(3)
                                                    .truncationMode(.tail)
                                                    .foregroundStyle(.primary)
                                                
                                                HStack(spacing: 6) {
                                                    if index < 5 {
                                                        Text("⌘\(index + 1)")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundStyle(.secondary)
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 2)
                                                            .background(Color.primary.opacity(0.08))
                                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                                    }
                                                    
                                                    ClipTypeTag(type: ClipboardContentType.detect(item.content))
                                                    
                                                    Text(item.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        ZStack(alignment: .trailing) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.green)
                                                .frame(width: 28, height: 28)
                                                .opacity(copiedItemId == item.id ? 1 : 0)
                                                .scaleEffect(copiedItemId == item.id ? 1 : 0.5)
                                                
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    withAnimation {
                                                        let isNowPinned = !item.isPinned
                                                        if isNowPinned {
                                                            item.isPinned = true
                                                            engine.itemDidPin(content: item.content)
                                                        } else {
                                                            engine.itemDidUnpin(item, context: modelContext)
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
                                            .opacity(copiedItemId == item.id ? 0 : 1)
                                        }
                                        .frame(width: 64, height: 28, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 8)
                                    .background(selectedIndex == index ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(selectedIndex == index ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                                    )
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
                        if let id = newId, selectedIndex == 0 {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < filteredItems.count {
                            proxy.scrollTo(filteredItems[newIndex].id, anchor: nil)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                        if let id = filteredItems.first?.id {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
            
            // ── Hidden Keyboard Navigation ──
            Group {
                Button("") {
                    if selectedIndex > 0 { selectedIndex -= 1 }
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                .opacity(0)
                
                Button("") {
                    if selectedIndex < filteredItems.count - 1 { selectedIndex += 1 }
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                .opacity(0)
                
                Button("") {
                    if !filteredItems.isEmpty && selectedIndex >= 0 && selectedIndex < filteredItems.count {
                        copyToClipboard(filteredItems[selectedIndex], autoClose: true)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .opacity(0)
                
                if !filteredItems.isEmpty {
                    ForEach(0..<min(5, filteredItems.count), id: \.self) { i in
                        Button("") {
                            copyToClipboard(filteredItems[i], autoClose: true)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                        .opacity(0)
                    }
                }
            }
            .frame(width: 0, height: 0)
        }
        .onChange(of: searchQuery) { _, _ in selectedIndex = 0 }
        .onChange(of: showPinnedOnly) { _, _ in selectedIndex = 0 }
    }
    
    private func copyToClipboard(_ item: ClipboardItem, autoClose: Bool = false) {
        engine.copyToClipboard(item.content)
        withAnimation(.spring) { copiedItemId = item.id }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if autoClose {
                NotificationCenter.default.post(name: NSNotification.Name("ClosePanelNotification"), object: nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if copiedItemId == item.id { copiedItemId = nil }
            }
        }
    }
}

