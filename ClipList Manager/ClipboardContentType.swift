import SwiftUI

// ── Content Type Detection ────────────────────────────────────────────
enum ClipboardContentType: CaseIterable {
    case url
    case email
    case phone
    case hexColor
    case json
    case code
    case number
    case text   // plain — no badge shown

    // MARK: - Visual properties


    var label: String {
        switch self {
        case .url:      return "URL"
        case .email:    return "Email"
        case .phone:    return "Phone"
        case .hexColor: return "Color"
        case .json:     return "JSON"
        case .code:     return "Code"
        case .number:   return "Number"
        case .text:     return "Text"
        }
    }

    var color: Color {
        switch self {
        case .url:      return .blue
        case .email:    return .purple
        case .phone:    return .green
        case .hexColor: return .orange
        case .json:     return Color(hue: 0.12, saturation: 0.8, brightness: 0.85)
        case .code:     return .indigo
        case .number:   return .teal
        case .text:     return .secondary
        }
    }

    // MARK: - Detection

    static func detect(_ text: String) -> ClipboardContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        // ── Hex color: #RGB, #RRGGBB, #RRGGBBAA ────────────────────
        if matches(trimmed, pattern: "^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$") {
            return .hexColor
        }

        // ── URL ─────────────────────────────────────────────────────
        if let url = URL(string: trimmed),
           let scheme = url.scheme,
           ["http", "https", "ftp", "ftps"].contains(scheme),
           url.host != nil {
            return .url
        }

        // ── Email ────────────────────────────────────────────────────
        if matches(trimmed, pattern: "^[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$") {
            return .email
        }

        // ── Phone ────────────────────────────────────────────────────
        let digitCount = trimmed.filter { $0.isNumber }.count
        if digitCount >= 7 && digitCount <= 15 &&
           matches(trimmed, pattern: "^[+]?[\\d\\s\\-().]{7,20}$") {
            return .phone
        }

        // ── JSON ─────────────────────────────────────────────────────
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .json
            }
        }

        // ── Code (heuristic) ─────────────────────────────────────────
        let codeKeywords = [
            "func ", "def ", "class ", "import ", "return ", "struct ",
            "const ", "let ", "var ", "if (", "for (", "while (",
            "console.log", "print(", "public ", "private ", "=>", "->"
        ]
        let hasKeyword  = codeKeywords.contains { trimmed.contains($0) }
        let hasSyntax   = (trimmed.contains("{") && trimmed.contains("}"))
                       || trimmed.contains("//")
                       || trimmed.contains("/*")
        let isMultiline = trimmed.contains("\n")
        if hasKeyword && (hasSyntax || isMultiline) { return .code }

        // ── Pure number ──────────────────────────────────────────────
        if trimmed.count <= 30 && digitCount > 0 &&
           matches(trimmed, pattern: "^[\\d,\\.\\-\\+\\s]+$") {
            return .number
        }

        return .text
    }

    // MARK: - Helpers

    private static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }
}

// ── Badge View ────────────────────────────────────────────────────────
struct ClipTypeTag: View {
    let type: ClipboardContentType

    var body: some View {
        Text(type.label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(type.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(type.color.opacity(0.12))
            .clipShape(Capsule())
    }
}
