import SwiftUI
import SwiftData
import ServiceManagement

struct SettingsPane: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAppearance") private var appAppearance: String = "System"
    @AppStorage("historyLimit") private var historyLimit: Int = 50
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    @State private var normalCleared = false
    @State private var pinnedCleared = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // ── Appearance & Startup ────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Appearance")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: $appAppearance) {
                                Text("System").tag("System")
                                Text("Light").tag("Light")
                                Text("Dark").tag("Dark")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Startup")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Toggle("Launch ClipList Manager at Login", isOn: $launchAtLogin)
                                .font(.system(size: 13))
                                .onChange(of: launchAtLogin) { _, newValue in
                                    do {
                                        if newValue {
                                            try SMAppService.mainApp.register()
                                        } else {
                                            try SMAppService.mainApp.unregister()
                                        }
                                    } catch {
                                        print("Failed to toggle launch at login: \(error)")
                                    }
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("History")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                
                            HStack(spacing: 8) {
                                TextField("Limit", value: $historyLimit, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.trailing)
                                    
                                Stepper("", value: $historyLimit, in: 1...500, step: 1)
                                    .labelsHidden()
                                    
                                Text("items to keep")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Data")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                
                            HStack(spacing: 8) {
                                Button(action: {
                                    do {
                                        try modelContext.delete(model: ClipboardItem.self, where: #Predicate { $0.isPinned == false })
                                        withAnimation { normalCleared = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { normalCleared = false } }
                                    } catch { print("Failed to delete normal items") }
                                }) {
                                    HStack {
                                        Image(systemName: normalCleared ? "checkmark.circle.fill" : "trash")
                                        Text(normalCleared ? "Cleared!" : "Clear Copied History")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(width: 140)
                                    .padding(.vertical, 5)
                                    .background(normalCleared ? Color.green : Color.primary.opacity(0.05))
                                    .foregroundStyle(normalCleared ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    do {
                                        try modelContext.delete(model: ClipboardItem.self, where: #Predicate { $0.isPinned == true })
                                        withAnimation { pinnedCleared = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { pinnedCleared = false } }
                                    } catch { print("Failed to delete pinned items") }
                                }) {
                                    HStack {
                                        Image(systemName: pinnedCleared ? "checkmark.circle.fill" : "trash")
                                        Text(pinnedCleared ? "Cleared!" : "Clear Pinned History")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(width: 140)
                                    .padding(.vertical, 5)
                                    .background(pinnedCleared ? Color.green : Color.primary.opacity(0.05))
                                    .foregroundStyle(pinnedCleared ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                             }
                        }
                    }
                    .padding(.bottom, 16)
                    
                    // ── About ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ClipList Manager")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Version 1.0")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(spacing: 6) {
                            InfoRow(label: "Developer", value: "Naveen Renati")
                            InfoRow(label: "Platform", value: "macOS 14+")
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
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

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
        }
    }
}
