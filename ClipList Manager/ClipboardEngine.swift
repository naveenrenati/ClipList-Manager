import Foundation
import AppKit
import SwiftData

@MainActor
final class ClipboardEngine: ObservableObject {
    private var timerTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0
    private var modelContext: ModelContext?
    
    /// In-memory set of content strings present in the UNPINNED history.
    /// Pinned items are intentionally excluded so pinning an item allows
    /// it to be re-copied into the normal (unpinned) history independently.
    private var knownContents: Set<String> = []

    func start(context: ModelContext) {
        self.modelContext = context
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        // Seed the in-memory set from UNPINNED items only.
        // Pinned items are excluded so they can coexist with a copy in normal history.
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { !$0.isPinned })
        if let existing = try? context.fetch(fetchDescriptor) {
            knownContents = Set(existing.map { $0.content })
        }
        
        // Use Swift Concurrency to poll the pasteboard safely on the MainActor
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if Task.isCancelled { break }
                self.checkForChanges()
            }
        }
    }
    
    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            processPasteboard(pasteboard)
        }
    }
    
    private func processPasteboard(_ pasteboard: NSPasteboard) {
        // We only care about strings for now to keep the app ultra-fast
        if let copiedString = pasteboard.string(forType: .string) {
            let trimmed = copiedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                saveToHistory(trimmed)
            }
        }
    }
    
    private func saveToHistory(_ text: String) {
        guard let context = modelContext else { return }
        
        // O(1) check — if this content already exists anywhere in history, skip it
        if knownContents.contains(text) { return }
        
        do {
            let newItem = ClipboardItem(content: text)
            context.insert(newItem)
            knownContents.insert(text)   // keep the set in sync
            try context.save()
            
            pruneHistory(context: context)
            
        } catch {
            print("Failed to save clipboard item: \(error)")
        }
    }
    
    // Public function to violently enforce the user's history limit at any time
    func pruneHistory(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            let items = try context.fetch(fetchDescriptor)
            
            let historyLimit = UserDefaults.standard.integer(forKey: "historyLimit")
            let limit = historyLimit > 0 ? historyLimit : 50 // Default to 50
            
            // Only count and prune UNPINNED items
            let unpinnedItems = items.filter { !$0.isPinned }
            if unpinnedItems.count > limit {
                let itemsToDelete = unpinnedItems.dropFirst(limit) // Keep exactly `limit` amount, delete the rest
                for item in itemsToDelete {
                    knownContents.remove(item.content)   // keep set in sync
                    context.delete(item)
                }
                try context.save()
            }
        } catch {
            print("Failed to prune history: \(error)")
        }
    }
    
    // Inject a string back into the clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Update the change count so the engine doesn't re-save what we just copied!
        self.lastChangeCount = pasteboard.changeCount
    }
    
    /// Call this when an unpinned item is pinned in the UI.
    /// Removes it from knownContents so copying the same text
    /// can create a fresh unpinned entry independently.
    func itemDidPin(content: String) {
        knownContents.remove(content)
    }
    
    /// Call this when a pinned item is unpinned in the UI.
    /// - If an unpinned copy already exists in history → delete the pinned item (avoid duplicate).
    /// - If no unpinned copy exists → unpin the item and register it in knownContents.
    func itemDidUnpin(_ item: ClipboardItem, context: ModelContext) {
        if knownContents.contains(item.content) {
            // A copy already exists in unpinned history — just delete this pinned item
            context.delete(item)
            try? context.save()
        } else {
            // No duplicate — unpin it and track it
            item.isPinned = false
            knownContents.insert(item.content)
            try? context.save()
        }
    }
}
