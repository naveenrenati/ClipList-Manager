import SwiftUI
import SwiftData
import ServiceManagement

struct SettingsPane: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAppearance") private var appAppearance: String = "System"
    @AppStorage("historyLimit") private var historyLimit: Int = 50
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    @State private var customShortcut: CustomShortcut = {
        if let data = UserDefaults.standard.data(forKey: "customGlobalShortcut"),
           let saved = try? JSONDecoder().decode(CustomShortcut.self, from: data) {
            return saved
        }
        return .defaultShortcut
    }()
    
    @State private var normalCleared = false
    @State private var pinnedCleared = false
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                // ── Appearance & Startup ────────────────────
                Section(header: Text("Behavior")) {
                    Picker("Theme", selection: $appAppearance) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch { print("Failed to toggle launch at login: \(error)") }
                        }
                    
                    LabeledContent("Global Shortcut") {
                        ShortcutRecorderView(shortcut: $customShortcut)
                            .controlSize(.small)
                            .onChange(of: customShortcut) { _, newShortcut in
                                if let data = try? JSONEncoder().encode(newShortcut) {
                                    UserDefaults.standard.set(data, forKey: "customGlobalShortcut")
                                    HotKeyManager.shared.registerHotKey(newShortcut)
                                }
                            }
                    }
                }
                
                // ── History & Data ───────────────────────────
                Section(header: Text("Data")) {
                    LabeledContent("Keep limit") {
                        HStack(spacing: 8) {
                            TextField("", value: $historyLimit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 45)
                                .multilineTextAlignment(.trailing)
                                
                            Stepper("", value: $historyLimit, in: 1...500, step: 1)
                                .labelsHidden()
                        }
                    }
                    
                    LabeledContent("Erase") {
                        HStack(spacing: 6) {
                            Button(action: {
                                do {
                                    try modelContext.delete(model: ClipboardItem.self, where: #Predicate { $0.isPinned == false })
                                    withAnimation { normalCleared = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { normalCleared = false } }
                                } catch { print("Failed to delete normal items") }
                            }) {
                                Text(normalCleared ? "Cleared!" : "Unpinned")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(normalCleared ? Color.green : Color.primary.opacity(0.1))
                                    .foregroundStyle(normalCleared ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                do {
                                    try modelContext.delete(model: ClipboardItem.self, where: #Predicate { $0.isPinned == true })
                                    withAnimation { pinnedCleared = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { pinnedCleared = false } }
                                } catch { print("Failed to delete pinned items") }
                            }) {
                                Text(pinnedCleared ? "Cleared!" : "Pinned")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(pinnedCleared ? Color.green : Color.primary.opacity(0.1))
                                    .foregroundStyle(pinnedCleared ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // ── About ────────────────────────────────────
                Section(header: Text("About")) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ClipList Manager")
                                .font(.system(size: 14, weight: .bold))
                            Text("Version 1.1")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    LabeledContent("Developer", value: "Naveen Renati")
                    LabeledContent("Compatibility", value: "macOS 14+")
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // ── Footer ────────────────────────────────────
            HStack {
                Link(destination: URL(string: "https://github.com/naveenrenati/ClipList-Manager")!) {
                    Text("GitHub")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("View Source Code on GitHub")

                Spacer()
                
                Button(role: .destructive, action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.8))
                .controlSize(.small)
            }
            .padding(14)
        }
    }
}
