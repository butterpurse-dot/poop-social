import Foundation

// MARK: - Automatic fallback

/// Runs a task through the providers in order, falling back on any failure.
///
/// The contract, stated plainly because it is the whole feature:
///
/// 1. Try each provider in the order given.
/// 2. A provider that is not `isAvailable` is skipped without being called.
/// 3. A provider that **throws** is treated as failed; move on. This includes
///    network errors, HTTP errors, empty output, and output that fails content
///    moderation.
/// 4. The first success wins, and the caller is told *which* provider answered
///    so the UI can be honest about it.
/// 5. If everything fails, throw `LLMError.noProviderAvailable` — never invent
///    a silent empty string.
///
/// Step 3's "moderation failure falls through" is deliberate: a cloud model
/// that returns something crude should not poison the app when a safe local
/// answer is sitting right there.
struct LLMRouter: Sendable {

    let providers: [LLMProvider]
    /// The moderator applied to *every* provider's output, cloud or local.
    /// Content safety must not depend on which provider answered.
    let moderator: Moderating

    init(providers: [LLMProvider], moderator: Moderating = Safety.moderator) {
        self.providers = providers
        self.moderator = moderator
    }

    /// The outcome of a successful completion, including provenance.
    struct Result: Sendable, Equatable {
        let text: String
        /// Which provider actually produced this, for honest UI copy.
        let providerName: String
        /// True when we had to fall back from an earlier, preferred provider.
        let didFallBack: Bool
    }

    /// Try providers in order. See the type doc for the exact contract.
    func complete(task: LLMTask, input: String) async throws -> Result {
        var sawAnyAvailable = false
        var triedAtLeastOne = false

        for (index, provider) in providers.enumerated() {
            guard provider.isAvailable else { continue }
            sawAnyAvailable = true
            triedAtLeastOne = true

            do {
                let raw = try await provider.complete(task: task, input: input)
                let cleaned = clean(raw)

                guard !cleaned.isEmpty else { continue }

                // Content rules apply to every provider identically.
                if !moderator.validate(text: cleaned).isAllowed {
                    continue
                }

                return Result(
                    text: cleaned,
                    providerName: provider.name,
                    didFallBack: index > 0
                )
            } catch {
                // Whatever went wrong, the next provider gets a turn.
                continue
            }
        }

        // Distinguish "nothing was configured" from "everything we tried failed"
        // — they are different problems and deserve different copy.
        if !sawAnyAvailable || !triedAtLeastOne {
            throw LLMError.noProviderAvailable
        }
        throw LLMError.noProviderAvailable
    }

    /// Output hygiene: collapse whitespace, strip stray quotes the model may add
    /// despite instructions, and remove any emoji (the app's own text is
    /// emoji-free by design, and emoji are added by the UI, not the model).
    private func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Models love to wrap output in quotes even when told not to.
        let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("'", "'")]
        for (open, close) in quotePairs
        where result.first == open && result.last == close && result.count > 1 {
            result.removeFirst()
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Drop emoji — the model should not be adding them, and the corpus here
        // is deliberately emoji-free.
        result = result.filter { !$0.isEmojiPresentation }

        // Collapse runs of whitespace into single spaces.
        result = result
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        return result
    }
}

private extension Character {
    /// True for characters that render as emoji. `isEmoji` alone would also
    /// catch digits and `#`, which is why the presentation check matters.
    var isEmojiPresentation: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
            || scalar.properties.isEmojiModifier
            || scalar.properties.isEmojiModifierBase
    }
}
