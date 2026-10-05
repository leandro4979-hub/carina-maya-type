import Foundation

struct Snippet: Identifiable, Codable, Equatable, Sendable {
    static let maximumCount = 100
    static let maximumShortcutLength = 32
    static let maximumReplacementLength = 500

    let id: UUID
    var shortcut: String
    var replacement: String
    var order: Int

    init(id: UUID = UUID(), shortcut: String, replacement: String, order: Int) {
        self.id = id
        self.shortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        self.replacement = replacement
        self.order = order
    }
}

enum SnippetValidationError: LocalizedError, Equatable {
    case emptyShortcut
    case emptyReplacement
    case shortcutTooLong
    case replacementTooLong
    case duplicateShortcut
    case tooManySnippets

    var errorDescription: String? {
        switch self {
        case .emptyShortcut: return "Shortcut cannot be empty."
        case .emptyReplacement: return "Replacement text cannot be empty."
        case .shortcutTooLong: return "Shortcut must be \(Snippet.maximumShortcutLength) characters or fewer."
        case .replacementTooLong: return "Replacement text must be \(Snippet.maximumReplacementLength) characters or fewer."
        case .duplicateShortcut: return "That shortcut already exists."
        case .tooManySnippets: return "You can save up to \(Snippet.maximumCount) snippets."
        }
    }
}

enum SnippetValidator {
    static func validate(_ snippet: Snippet, among snippets: [Snippet]) throws {
        guard !snippet.shortcut.isEmpty else { throw SnippetValidationError.emptyShortcut }
        guard !snippet.replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SnippetValidationError.emptyReplacement
        }
        guard snippet.shortcut.count <= Snippet.maximumShortcutLength else {
            throw SnippetValidationError.shortcutTooLong
        }
        guard snippet.replacement.count <= Snippet.maximumReplacementLength else {
            throw SnippetValidationError.replacementTooLong
        }

        let normalized = snippet.shortcut.lowercased()
        guard !snippets.contains(where: { $0.id != snippet.id && $0.shortcut.lowercased() == normalized }) else {
            throw SnippetValidationError.duplicateShortcut
        }

        let isNew = !snippets.contains(where: { $0.id == snippet.id })
        if isNew && snippets.count >= Snippet.maximumCount {
            throw SnippetValidationError.tooManySnippets
        }
    }
}

enum SnippetMatcher {
    static func activeTrigger(in context: String) -> String? {
        let token = context
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .last
            .map(String.init) ?? ""

        guard token.hasPrefix(";"), token.count > 1 else { return nil }
        return token
    }

    static func matches(context: String, snippets: [Snippet], limit: Int = 3) -> [Snippet] {
        guard let trigger = activeTrigger(in: context)?.lowercased() else { return [] }

        return snippets
            .filter { $0.shortcut.lowercased().hasPrefix(trigger) }
            .sorted {
                if $0.order == $1.order {
                    return $0.shortcut.localizedCaseInsensitiveCompare($1.shortcut) == .orderedAscending
                }
                return $0.order < $1.order
            }
            .prefix(max(0, limit))
            .map { $0 }
    }
}
