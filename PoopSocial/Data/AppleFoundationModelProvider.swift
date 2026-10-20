import Foundation

// MARK: - Apple's Foundation Models, behind the same seam
//
// Apple's Foundation Models framework is the best default here, and it is worth
// being explicit about why:
//
//   * **No API key.** There is nothing to store, leak, or bill.
//   * **No cost per request**, on-device. Apple's stated terms.
//   * **Works offline.** The on-device model needs no network at all.
//   * **Private by construction.** On-device data never leaves the phone;
//     Private Cloud Compute stores no prompts and is independently verifiable.
//
// That beats a user-supplied cloud key on every axis except raw capability —
// which is why Private Cloud Compute sits in front of the cloud-key provider but
// behind on-device.
//
// ## API notes (verified against Apple's documentation, not guessed)
//
//   * The on-device model is `SystemLanguageModel.default` — there is a
//     `default` accessor, and `SystemLanguageModel()` is not the idiomatic form.
//   * Availability is `model.availability`, an enum with `.available` and
//     `.unavailable(reason)`. `isAvailable` is the boolean convenience.
//   * A session is `LanguageModelSession(model:instructions:)`, where
//     `instructions` is an `Instructions` value. The trailing-closure form
//     `LanguageModelSession(model:model) { "..." }` is equivalent.
//   * `respond(to:)` returns `Response<String>`; the text is `.content`.
//   * The documented error type is `LanguageModelSession.GenerationError`.
//     Apple deprecates it in the 27 SDK in favour of `LanguageModelError` /
//     `SystemLanguageModel.Error` / `LanguageModelSession.Error`, so this code
//     catches generically and does not depend on the case names.
//   * Private Cloud Compute is `PrivateCloudComputeLanguageModel`, available
//     from **iOS 27**, and needs the network plus a per-person daily allowance.
//     It is an enhanced path, never the floor.
//
// ## Why this file is guarded
//
// The framework requires the iOS 26 SDK. This project is developed on an Intel
// iMac capped at Xcode 15.2 / iOS 17, so without the `#if` the whole app would
// stop compiling on the developer's own machine. The guard means:
//
//   * Xcode 15.2 → the type still exists, reports `isAvailable == false`, and
//     the router skips it. Nothing breaks, nothing dangles.
//   * Xcode 26/27 → it compiles for real and is used automatically, in order,
//     ahead of the cloud-key provider.
//
// One codebase, honest on both toolchains, no maintenance branch.

/// Provider backed by Apple's on-device model, or Private Cloud Compute.
///
/// `isAvailable` is the important part: it reports `false` on anything that
/// cannot run the model *right now* — older SDK, ineligible hardware, Apple
/// Intelligence switched off, or the model still downloading — so the router
/// falls through to the next provider without special-casing any of it.
struct AppleFoundationModelProvider: LLMProvider {

    /// `true` for the Private Cloud Compute model, `false` for on-device.
    let usePrivateCloud: Bool

    var name: String {
        usePrivateCloud ? "Apple Private Cloud" : "Apple on-device"
    }

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if usePrivateCloud {
            // PCC is iOS 27+ and needs a network, so it can vanish at any
            // moment. Availability is checked at call time, never cached.
            guard #available(iOS 27.0, *) else { return false }
            return AppleFM.availability(of: .privateCloud) == .available
        } else {
            guard #available(iOS 26.0, *) else { return false }
            return AppleFM.availability(of: .onDevice) == .available
        }
        #else
        // Framework absent (older SDK): this provider simply does not exist.
        return false
        #endif
    }

    func complete(task: LLMTask, input: String) async throws -> String {
        #if canImport(FoundationModels)
        return try await AppleFM.complete(
            systemPrompt: task.systemPrompt,
            input: input,
            usePrivateCloud: usePrivateCloud
        )
        #else
        throw LLMError.noProviderAvailable
        #endif
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// The thin part that actually touches Apple's API.
///
/// Kept separate from the provider so the `#available` checks and the framework
/// import live in exactly one place, and so the rest of the app never sees these
/// symbols. The provider above is the only entry point.
enum AppleFM {

    /// Which Apple model we are asking about.
    enum Kind {
        case onDevice
        case privateCloud
    }

    /// What we know about the model, flattened into cases the router cares about
    /// rather than the framework's richer enum. `.available` is the only value
    /// that means "go"; everything else means "move on".
    enum Availability {
        case available
        case unavailable
    }

    /// Is a usable model present right now?
    ///
    /// Deliberately conservative. Apple Intelligence can be *off* (user
    /// setting), *unsupported* (older hardware), *disabled by a guardian/region
    /// rule*, or *still downloading*. Every one of those must report unavailable
    /// so the router moves on rather than hanging on a request that can never
    /// answer.
    static func availability(of kind: Kind) -> Availability {
        switch kind {
        case .onDevice:
            guard #available(iOS 26.0, *) else { return .unavailable }
            // `SystemLanguageModel.default` is the documented accessor.
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable:
                return .unavailable
            }

        case .privateCloud:
            guard #available(iOS 27.0, *) else { return .unavailable }
            switch PrivateCloudComputeLanguageModel().availability {
            case .available:
                return .available
            case .unavailable:
                return .unavailable
            }
        }
    }

    /// Generate text with the chosen Apple model.
    ///
    /// Throws `LLMError` so the router's fallback logic is uniform: a thrown
    /// error from here is indistinguishable, to the router, from a thrown error
    /// from the cloud provider. That uniformity is the whole point of the seam.
    static func complete(
        systemPrompt: String,
        input: String,
        usePrivateCloud: Bool
    ) async throws -> String {
        let kind: Kind = usePrivateCloud ? .privateCloud : .onDevice

        guard availability(of: kind) == .available else {
            throw LLMError.noProviderAvailable
        }

        let session: LanguageModelSession
        switch kind {
        case .onDevice:
            guard #available(iOS 26.0, *) else { throw LLMError.noProviderAvailable }
            session = LanguageModelSession(model: SystemLanguageModel.default) {
                Instructions(systemPrompt)
            }

        case .privateCloud:
            guard #available(iOS 27.0, *) else { throw LLMError.noProviderAvailable }
            session = LanguageModelSession(model: PrivateCloudComputeLanguageModel()) {
                Instructions(systemPrompt)
            }
        }

        let text: String
        do {
            let response = try await session.respond(to: input)
            text = response.content
        } catch {
            // Catching generically on purpose. Apple renames these error types
            // in the 27 SDK (`GenerationError` → `LanguageModelError` /
            // `SystemLanguageModel.Error` / `LanguageModelSession.Error`), and
            // Apple's own deprecation note warns that a stale `catch
            // GenerationError.exceededContextWindowSize` silently stops matching
            // after a rebuild. Depending only on "it threw" keeps this correct
            // across both SDKs; the router treats every throw the same way.
            throw LLMError.transport(String(describing: error))
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMError.emptyResponse }
        return trimmed
    }
}
#endif
