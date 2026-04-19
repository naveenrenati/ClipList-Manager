import Foundation
import AppKit
import SwiftData

@MainActor
final class ClipboardEngine: ObservableObject {
    private var timerTask: Task<Void, Never>?
    private var lastChangeCount: Int = 0
    private var modelContext: ModelContext?
    
    func start(context: ModelContext) {
        self.modelContext = context
        self.lastChangeCount = NSPasteboard.general.changeCount
        
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
        
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            let items = try context.fetch(fetchDescriptor)
            
            // Prevent identical back-to-back duplicates
            if let first = items.first, first.content == text {
                return
            }
            
            let newItem = ClipboardItem(content: text)
            context.insert(newItem)
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
}
