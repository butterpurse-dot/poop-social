import Foundation

/// What the rest of the app calls. Owns the provider list so nobody else has to
/// think about ordering, keys or fallback.
///
/// This file lives in the **app target only**, not the unit-test bundle: it
/// wires in `HygieneTips` and `JokeBank`, which import SwiftUI for their theme
/// colours. The router and providers themselves stay pure so they can be tested
/// without a simulator.
///
/// ## Provider order
///
/// 1. **Apple on-device** (Foundation Models) — free, offline, private, and the
///    best default. Only on iOS 26+ with Apple Intelligence; `#if`-guarded.
/// 2. **Apple Private Cloud Compute** — free to small developers, far more
///    capable than on-device, and still private. Also iOS 26+ only.
/// 3. **Cloud key** (OpenAI-compatible) — optional, user-supplied. Skipped
///    entirely when no key is set.
/// 4. **Local corpus** — always available. The floor.
///
/// Steps 1–3 are all skipped cleanly when unavailable, so an install with no API
/// key and no Apple Intelligence behaves as if it were corpus-only: no error, no
/// dead feature. That is the entire point of the seam.
@MainActor
final class LLM {

    static let shared = LLM()

    private var router: LLMRouter
    private(set) var cloudEnabled: Bool

    private let keyStore: LLMKeyStore
    private let baseURL: URL
    private let model: String

    init(
        keyStore: LLMKeyStore = .shared,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        model: String = "gpt-4o-mini"
    ) {
        self.keyStore = keyStore
        self.baseURL = baseURL
        self.model = model

        let key = keyStore.apiKey()
        self.cloudEnabled = !(key ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        self.router = LLMRouter(providers: Self.providers(
            apiKey: key, baseURL: baseURL, model: model
        ))
    }

    /// Rebuild after the user saves or clears a key.
    func refresh(apiKey: String?) {
        let cleaned = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        cloudEnabled = !cleaned.isEmpty
        router = LLMRouter(providers: Self.providers(
            apiKey: cleaned.isEmpty ? nil : cleaned, baseURL: baseURL, model: model
        ))
    }

    /// Generate text, falling back automatically.
    func text(task: LLMTask, input: String) async throws -> LLMRouter.Result {
        try await router.complete(task: task, input: input)
    }

    // MARK: - Provider assembly

    /// Build the ordered provider list for the current device and configuration.
    ///
    /// The Apple providers are constructed only inside `#if canImport(...)`, so
    /// this file still compiles on Xcode 15 / iOS 17 where the framework does not
    /// exist. On a modern toolchain they simply appear in the list, and the
    /// router skips them if the OS or hardware can't run them.
    private static func providers(
        apiKey: String?,
        baseURL: URL,
        model: String
    ) -> [LLMProvider] {
        var list: [LLMProvider] = []

        #if canImport(FoundationModels)
        list.append(AppleFoundationModelProvider(usePrivateCloud: false))
        list.append(AppleFoundationModelProvider(usePrivateCloud: true))
        #endif

        list.append(CloudLLMProvider(baseURL: baseURL, model: model, apiKey: apiKey))
        list.append(local())
        return list
    }

    /// The local corpus provider, wired to the app's real data.
    ///
    /// `HygieneTips.blurb` and `JokeBank.text` are the curated corpora the app
    /// already ships, which is what makes this a genuine fallback rather than a
    /// placeholder.
    static func local() -> LocalLLMProvider {
        LocalLLMProvider(
            hygieneCorpus: { HygieneTips.all.map(\.blurb) },
            jokeCorpus: { JokeBank.all.map(\.text) }
        )
    }
}
