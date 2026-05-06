import SwiftUI
import AppKit
import Carbon

// ── Model ────────────────────────────────────────────────────────────
struct CustomShortcut: Codable, Equatable {
    var keyCode: UInt16
    var carbonModifiers: UInt32
    var displayString: String
    
    // Default: Cmd + Shift + V
    static let defaultShortcut = CustomShortcut(keyCode: 9, carbonModifiers: UInt32(cmdKey | shiftKey), displayString: "⇧⌘V")
}

// ── SwiftUI View ──────────────────────────────────────────────────────
struct ShortcutRecorderView: View {
    @Binding var shortcut: CustomShortcut
    @State private var isRecording = false
    
    var body: some View {
        Button(action: {
            isRecording = true
        }) {
            Text(isRecording ? "Listening..." : shortcut.displayString)
                .frame(width: 100)
                .padding(.vertical, 4)
        }
        .background(ShortcutCaptureView(shortcut: $shortcut, isRecording: $isRecording).frame(width: 0, height: 0))
    }
}

// ── NSViewRepresentable ──────────────────────────────────────────────
struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var shortcut: CustomShortcut
    @Binding var isRecording: Bool
    
    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = { newShortcut in
            self.shortcut = newShortcut
            self.isRecording = false
        }
        return view
    }
    
    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

// ── NSView for capturing KeyDown ─────────────────────────────────────
class CaptureNSView: NSView {
    var isRecording = false
    var onCapture: ((CustomShortcut) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Must have at least one modifier to be a valid global shortcut
        guard !modifiers.isEmpty, let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            return
        }
        
        var carbonMods: UInt32 = 0
        var displayStr = ""
        
        if modifiers.contains(.control) { carbonMods |= UInt32(controlKey); displayStr += "⌃" }
        if modifiers.contains(.option) { carbonMods |= UInt32(optionKey); displayStr += "⌥" }
        if modifiers.contains(.shift) { carbonMods |= UInt32(shiftKey); displayStr += "⇧" }
        if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey); displayStr += "⌘" }
        
        displayStr += chars.uppercased()
        
        let newShortcut = CustomShortcut(
            keyCode: event.keyCode,
            carbonModifiers: carbonMods,
            displayString: displayStr
        )
        onCapture?(newShortcut)
    }
}
