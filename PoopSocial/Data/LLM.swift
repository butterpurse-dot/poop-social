import Foundation

// MARK: - The LLM seam
//
// Same shape as the moderation seam (`Moderating` → `LocalModerator`): one
// protocol, several implementations, and a resolver that picks one. Call sites
// never know which provider answered.
//
// Why a protocol and not just "call OpenAI": so the app never *depends* on a
// network, a key, or a vendor. Offline, unkeyed, or rate-limited all have to
// resolve to something that works — that's the whole point of the local
// fallback.

/// What we want an LLM to do. Deliberately tiny — this app needs short, funny
/// text, not a chat transcript, so the surface stays small enough to fake well.
enum LLMTask: String, Codable, CaseIterable {
    /// Suggest hygiene-tip phrasing in the app's voice.
    case hygieneTip
    /// Write an original one-liner in the style of the existing joke bank.
    case oneLiner
    /// Turn a terse review into a slightly funnier note.
    case reviewPunchUp

    var systemPrompt: String {
        switch self {
        case .hygieneTip:
            return """
            You write short, genuinely useful bathroom-hygiene tips for a playful social app. \
            One or two sentences. Concrete and actionable. Warm and lightly funny, never crude. \
            No emoji. No preamble, no quotes — output the tip and nothing else.
            """
        case .oneLiner:
            return """
            You write original one-liners in the voice of a bathroom-humour social app: \
            internet slang, group-chat deadpan, trailer-voice drama about mundane things. \
            One sentence, under 120 characters, no emoji, no hashtags. \
            Never reference existing films, shows or brands. \
            Output only the line, no quotes, no preamble.
            """
        case .reviewPunchUp:
            return """
            You punch up a short bathroom review so it lands funnier while keeping the \
            original meaning and any facts intact. One or two sentences, no emoji, \
            no slurs, nothing crude about bodies. Output only the rewritten text.
            """
        }
    }
}

/// A provider is anything that can turn a prompt into text.
///
/// `async` from the start because the cloud path is inherently async; making the
/// local path async too keeps the two swappable without changing call sites.
protocol LLMProvider: Sendable {
    /// Human-readable name, for the settings screen and for explaining *which*
    /// provider actually answered.
    var name: String { get }

    /// Whether this provider is usable right now (key present, model bundled…).
    var isAvailable: Bool { get }

    /// Generate a completion. Throwing is expected and normal — the resolver
    /// treats a throw as "try the next provider".
    func complete(task: LLMTask, input: String) async throws -> String
}

enum LLMError: Error, Equatable {
    /// No provider was configured or available at all.
    case noProviderAvailable
    /// A provider was reachable but returned something unusable.
    case emptyResponse
    /// The response failed the content rules (see `Safety.moderator`).
    case rejectedByModeration(reason: String)
    case transport(String)
}

// MARK: - The local provider

/// A dependency-free local "model".
///
/// This is an honest implementation, not a stub that pretends: it composes
/// real output from whatever corpora it is handed, deterministically, with no
/// network and no key. That makes it a genuine fallback — the feature still
/// works on a plane, or before the user ever enters an API key.
///
/// The corpora are **injected** rather than read from `HygieneTips`/`JokeBank`
/// directly. Two reasons: those types import SwiftUI (they carry `Theme`
/// colours), which would drag the whole UI stack into the unit-test bundle; and
/// injection lets tests substitute fixed corpora and assert exact output.
///
/// It is *not* a neural network and says so. When a real local model (e.g. a
/// bundled Core ML / llama.cpp build) is available, conform it to `LLMProvider`
/// and slot it in; nothing else changes.
struct LocalLLMProvider: LLMProvider {
    let name = "On-device"

    /// Supplies candidate hygiene takeaways. Empty is tolerated and falls back
    /// to a built-in safe line.
    var hygieneCorpus: @Sendable () -> [String]
    /// Supplies candidate one-liners. Same tolerance.
    var jokeCorpus: @Sendable () -> [String]

    init(
        hygieneCorpus: (@Sendable () -> [String])? = nil,
        jokeCorpus: (@Sendable () -> [String])? = nil
    ) {
        self.hygieneCorpus = hygieneCorpus ?? { LocalLLMProvider.defaultHygiene }
        self.jokeCorpus = jokeCorpus ?? { LocalLLMProvider.defaultJokes }
    }

    /// Always available. That is the point.
    var isAvailable: Bool { true }

    func complete(task: LLMTask, input: String) async throws -> String {
        let seed = Self.stableSeed(from: input + task.rawValue)

        switch task {
        case .hygieneTip:
            let tips = hygieneCorpus()
            guard !tips.isEmpty else { return Self.defaultHygiene[0] }
            return tips[seed % tips.count]

        case .oneLiner:
            let lines = jokeCorpus()
            guard !lines.isEmpty else { return Self.defaultJokes[0] }
            return lines[seed % lines.count]

        case .reviewPunchUp:
            // Local "punch-up" is a light rephrase that cannot invent claims:
            // it only trims and reshapes what it was given.
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw LLMError.emptyResponse }
            return Self.punchUp(trimmed)
        }
    }

    /// Small built-in corpora so the provider is self-sufficient even when the
    /// app's data layer is unavailable (and so unit tests need no fixtures).
    static let defaultHygiene: [String] = [
        "Soap, friction and about twenty seconds — that combination is the whole trick.",
        "Dry your hands completely. Wet hands spread more germs than dry ones.",
        "Use a paper towel to touch the door handle on the way out.",
        "Keep your phone out of the bathroom, or wipe it after.",
    ]

    static let defaultJokes: [String] = [
        "That wasn't a bathroom break. That was a factory reset.",
        "Walked in a mortal. Walked out a legend.",
        "Five stars. Would flush again.",
        "Cleared my cache and my calendar.",
    ]

    /// A deterministic hash so the same input yields the same output.
    ///
    /// Determinism matters for two reasons: the UI can cache/animate without
    /// flicker, and tests can assert on exact values without flaking.
    /// (`String.hashValue` is deliberately NOT used — it is randomly seeded per
    /// process, which would make the local provider non-reproducible.)
    static func stableSeed(from string: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325  // FNV-1a offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3      // FNV prime
        }
        return Int(hash % UInt64(Int.max))
    }

    /// Keeps the original sentence but gives it a little lift. Never adds facts,
    /// because there are none to add locally.
    static func punchUp(_ text: String) -> String {
        let body = text.trimmingCharacters(in: CharacterSet(charactersIn: ".! "))
        guard !body.isEmpty else { return text }
        if body.hasSuffix("!") { return text }
        return body + ". I said what I said."
    }
}

// MARK: - The cloud provider

/// Talks to an OpenAI-compatible chat-completions endpoint.
///
/// OpenAI-compatible rather than OpenAI-specific on purpose: the same code works
/// against OpenAI, Groq, Together, OpenRouter, or a self-hosted server by
/// changing `baseURL`. That keeps the vendor choice reversible.
///
/// The key is read from the Keychain, never `UserDefaults` and never a plist —
/// see `LLMKeyStore`.
struct CloudLLMProvider: LLMProvider {
    let name: String
    let baseURL: URL
    let model: String
    let apiKey: String?

    /// A short timeout is intentional: a slow cloud call should hand over to the
    /// local provider quickly rather than leave the user waiting.
    var timeout: TimeInterval = 8

    init(
        name: String = "Cloud",
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        model: String = "gpt-4o-mini",
        apiKey: String?,
        timeout: TimeInterval = 8
    ) {
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.timeout = timeout
    }

    var isAvailable: Bool {
        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return true
    }

    func complete(task: LLMTask, input: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw LLMError.noProviderAvailable }

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: task.systemPrompt),
                .init(role: "user", content: input)
            ],
            temperature: 0.9,
            max_tokens: 120
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LLMError.transport("HTTP \(http.statusCode)")
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw LLMError.transport("malformed response")
        }

        let text = decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }

    // MARK: Wire format

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        /// Separate from `ChatRequest.Message` on purpose: that one is
        /// `Encodable`-only (it is what we *send*), and reusing it here fails to
        /// decode. Decoding only needs `role`/`content`, and `content` is the
        /// only field this app reads.
        struct Message: Decodable {
            let role: String
            let content: String
        }
    }
}
