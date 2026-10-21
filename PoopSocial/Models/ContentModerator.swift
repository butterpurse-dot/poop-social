import Foundation

// MARK: - Content safety
//
// House rule: **no photos of bodily business, ever.**
// Enforced structurally, not by vibes:
//
//   1. No camera, no image picker, no attachment affordance exists in the UI.
//   2. `MediaKind` has no image case — it is impossible to construct one.
//   3. Every outbound piece of user content passes `Moderating`.
//
// Swap `LocalModerator` for a server-side classifier by conforming to `Moderating`.
// Call sites never change.

enum MediaKind: String, Codable, CaseIterable, Identifiable {
    case emoji
    case textLine
    case quoteCard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .emoji:     return "Emoji"
        case .textLine:  return "One-liner"
        case .quoteCard: return "Quote card"
        }
    }
}

enum BlockReason: Equatable {
    case noImagesAllowed
    case flaggedLanguage
    case tooLong
    case empty

    var title: String {
        switch self {
        case .noImagesAllowed: return "Nice try 🚫📸"
        case .flaggedLanguage: return "Let's keep it civil"
        case .tooLong:         return "That's a lot of words"
        case .empty:           return "Say something first"
        }
    }

    var detail: String {
        switch self {
        case .noImagesAllowed: return "Photos don't belong here. Send an emoji or a one-liner instead."
        case .flaggedLanguage: return "Rephrase that one — this is a friendly bathroom."
        case .tooLong:         return "Trim it down to the funny part."
        case .empty:           return "Empty posts get zero laughs."
        }
    }

    var emoji: String {
        switch self {
        case .noImagesAllowed: return "🚽"
        case .flaggedLanguage: return "🧼"
        case .tooLong:         return "✂️"
        case .empty:           return "💭"
        }
    }
}

enum ModerationVerdict: Equatable {
    case allowed
    case blocked(BlockReason)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    var reason: BlockReason? {
        if case .blocked(let r) = self { return r }
        return nil
    }
}

protocol Moderating: Sendable {
    func validate(text: String) -> ModerationVerdict
    func validateMedia(_ kind: MediaKind) -> ModerationVerdict
    func validateEmoji(_ emoji: String) -> ModerationVerdict
    func sanitize(_ text: String) -> String
}

struct LocalModerator: Moderating {

    static let maxLength = 220

    static let flaggedTerms: Set<String> = [
        "nsfw", "nude", "naked", "explicit", "gore", "xxx"
    ]

    /// Curated safe palette. Deliberately excludes anything graphic.
    static let approvedEmoji: [String] = [
        "🚽", "🧻", "🧼", "🫧", "🚿", "✨", "💀", "🫥", "😬", "🤢",
        "😌", "🤩", "👏", "🔥", "💯", "🫡", "🙌", "😭", "😅", "🤝",
        "💖", "⚠️", "🧯", "🎯", "🏆", "🪠", "🧽", "🪥", "🛡️", "🚀"
    ]

    func validate(text: String) -> ModerationVerdict {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .blocked(.empty) }
        guard trimmed.count <= Self.maxLength else { return .blocked(.tooLong) }

        let lowered = trimmed.lowercased()
        for term in Self.flaggedTerms where lowered.contains(term) {
            return .blocked(.flaggedLanguage)
        }
        return .allowed
    }

    /// The single media choke point. Images are unrepresentable by design.
    /// Only the three known non-image kinds are allowed; anything else is
    /// rejected immediately rather than falling through. This is the structural
    /// enforcement: `MediaKind` has no image case, and even if a future update
    /// accidentally added `.photo` (or `.nude`, `.video`), the validator blocks
    /// it by default rather than relying solely on the enum's absence.
    ///
    /// Before: `.allowed` unconditionally for any kind, so an unknown kind
    /// silently passed. After: `.allowed` only for the known-safe set.
    func validateMedia(_ kind: MediaKind) -> ModerationVerdict {
        switch kind {
        case .emoji, .textLine, .quoteCard:
            return .allowed
        default:
            // Defensive: `default` catches any future case added without an
            // explicit approval decision. This aligns with the structural policy:
            // if it was not explicitly named safe, it is not safe.
            return .blocked(.noImagesAllowed)
        }
    }

    func validateEmoji(_ emoji: String) -> ModerationVerdict {
        Self.approvedEmoji.contains(emoji) ? .allowed : .blocked(.noImagesAllowed)
    }

    func sanitize(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if collapsed.count > Self.maxLength {
            return String(collapsed.prefix(Self.maxLength - 1)) + "…"
        }
        return collapsed
    }
}

enum Safety {
    static let moderator: Moderating = LocalModerator()
}
