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
//   * `SystemLanguageModel.default` is the on-device model. `SystemLanguageModel()`
//     also exists, but `default` is the documented accessor for the general model.
//   * Availability is `model.availability` (an enum with `.available` /
//     `.unavailable`, the latter carrying a reason) or the `isAvailable`
//     convenience. Both are used below.
//   * A session is `LanguageModelSession(model:instructions:)`, where a trailing
//     closure supplies `Instructions`. `respond(to:)` returns `Response<String>`
//     and the text is `.content`.
//   * **Private Cloud Compute is `PrivateCloudComputeLanguageModel`, available
//     from iOS 27.0**, and it needs the network plus the managed PCC entitlement.
//     It is an enhanced path, never the floor.
//
// ## The availability trap this file exists to get right
//
// Every one of these symbols is annotated `@available(iOS 26.0, *)` or `27.0`.
// `#if canImport(FoundationModels)` answers "does this *module* exist on this
// toolchain?" — which is `true` on an Xcode 26 build. It does **not** answer
// "may I call this API given my deployment target", and this app targets iOS 17.
//
// That distinction produced a real CI failure:
//
//     error: 'LanguageModelSession' is only available in iOS 26.0 or newer
//     error: 'respond(to:options:)' is only available in iOS 26.0 or newer
//     error: cannot find 'PrivateCloudComputeLanguageModel' in scope
//
// The last one is the same mistake wearing a different hat: the type is iOS 27,
// so on a build that only knows about an earlier availability context it is not
// merely unusable, it is absent.
//
// The lesson is that a `guard #available(...) else { return }` does **not**
// extend availability to the rest of a function — especially not to a
// declaration with an explicit type annotation. The compiler needs the gated
// code in a scope that is *annotated* `@available`. Hence the shape below:
// each iOS-version-specific call lives in its own tiny `@available` function,
// and the public entry point is a plain `if #available` dispatch.
//
// ## Why the whole file is `#if`-guarded
//
// On Xcode 15.2 (all this hardware-capped Intel iMac can run) the framework does
// not exist at all, so the module check is exactly the right guard there:
// the provider compiles to something that reports `isAvailable == false` and the
// router skips it. On Xcode 26/27 the module check passes, the `@available`
// dispatch below handles the deployment-target gap, and the providers light up
// automatically. One codebase, honest on both toolchains, no maintenance branch.

/// Provider backed by Apple's on-device model, or Private Cloud Compute.
///
/// `isAvailable` is the important part: it reports `false` on anything that
/// cannot run the model *right now* — older OS, ineligible hardware, Apple
/// Intelligence switched off, missing PCC entitlement, or the model still
/// downloading — so the router falls through to the next provider without
/// special-casing any of it.
struct AppleFoundationModelProvider: LLMProvider {

    /// `true` for the Private Cloud Compute model, `false` for on-device.
    let usePrivateCloud: Bool

    var name: String {
        usePrivateCloud ? "Apple Private Cloud" : "Apple on-device"
    }

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        return AppleFM.isAvailable(usePrivateCloud ? .privateCloud : .onDevice)
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

    // MARK: - Availability

    /// Is a usable model present right now?
    ///
    /// Deliberately conservative. Apple Intelligence can be *off* (user
    /// setting), *unsupported* (older hardware), *disabled by a region or
    /// guardian rule*, *still downloading*, or the PCC entitlement can be
    /// missing. Every one of those must report unavailable so the router moves
    /// on rather than hanging on a request that can never answer.
    ///
    /// The `if #available` dispatch is at this level rather than inside the
    /// gated helpers, because calling an `@available(iOS 26, *)` function is
    /// itself what requires the check.
    static func isAvailable(_ kind: Kind) -> Bool {
        switch kind {
        case .onDevice:
            if #available(iOS 26.0, *) {
                return onDeviceIsAvailable()
            }
            return false

        case .privateCloud:
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                return privateCloudIsAvailable()
            }
            #endif
            // PCC needs the iOS 27 SDK. On the Xcode 26 SDK the type does not
            // exist at all, so this is the correct answer there, not a fallback.
            return false
        }
    }

    /// On-device availability. Only ever called from an iOS 26+ context.
    ///
    /// Annotated `@available` so the compiler can prove the framework calls
    /// inside it are legal, which a `guard` at the call site could not do.
    @available(iOS 26.0, *)
    private static func onDeviceIsAvailable() -> Bool {
        // `isAvailable` is the documented convenience over the richer
        // `availability` enum, and it is all the router needs: one boolean.
        return SystemLanguageModel.default.isAvailable
    }

    /// PCC availability. iOS 27+ only, and iOS 27 means the Xcode 27 SDK.
    ///
    /// Guarded by `#if compiler(>=6.4)` at the call site rather than only by
    /// `@available`, because `PrivateCloudComputeLanguageModel` does not exist
    /// in the iOS 26.5 SDK at all. `@available` can gate the *use* of a type; it
    /// cannot make a type that is missing from the SDK appear, so on Xcode 26.6
    /// this produced `cannot find 'PrivateCloudComputeLanguageModel' in scope`
    /// even while wearing an `@available(iOS 27.0, *)` annotation.
    ///
    /// Version mapping, from Apple's own compatibility table:
    ///   Xcode 26.6 -> Swift 6.3, iOS 26.5 SDK, no PCC
    ///   Xcode 27   -> Swift 6.4, iOS 27 SDK, has PCC
    ///
    /// The function itself is inside the `#if` as well, not just its call
    /// sites: it is the *body* that names the missing type, so leaving it
    /// compiled on Xcode 26 still fails with "cannot find ... in scope".
    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private static func privateCloudIsAvailable() -> Bool {
        return PrivateCloudComputeLanguageModel().isAvailable
    }
    #endif

    // MARK: - Generation

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

        guard isAvailable(kind) else { throw LLMError.noProviderAvailable }

        switch kind {
        case .onDevice:
            // Belt and braces: `isAvailable` already proved iOS 26+, but the
            // compiler needs the check in the *same* scope as the call.
            if #available(iOS 26.0, *) {
                return try await completeOnDevice(systemPrompt: systemPrompt, input: input)
            }
            throw LLMError.noProviderAvailable

        case .privateCloud:
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                return try await completeOnPrivateCloud(systemPrompt: systemPrompt, input: input)
            }
            #endif
            throw LLMError.noProviderAvailable
        }
    }

    /// On-device generation. iOS 26+ only.
    @available(iOS 26.0, *)
    private static func completeOnDevice(
        systemPrompt: String,
        input: String
    ) async throws -> String {
        let session = LanguageModelSession(model: SystemLanguageModel.default) {
            Instructions(systemPrompt)
        }
        return try await text(from: session, input: input)
    }

    /// Private Cloud Compute generation. iOS 27+ only, and therefore Xcode 27+
    /// only, because the type is absent from the iOS 26.5 SDK.
    ///
    /// Guarded by `#if compiler(>=6.4)` so this function is not compiled at all
    /// on Xcode 26 — the reference inside it would not resolve there.
    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private static func completeOnPrivateCloud(
        systemPrompt: String,
        input: String
    ) async throws -> String {
        let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel()) {
            Instructions(systemPrompt)
        }
        return try await text(from: session, input: input)
    }
    #endif

    /// Send the prompt and extract the text, with the error handling and
    /// output cleaning shared by both models.
    ///
    /// Note the generic `catch`. Apple renames these error types in the 27 SDK
    /// (`GenerationError` → `LanguageModelError` / `SystemLanguageModel.Error` /
    /// `LanguageModelSession.Error`), and Apple's own deprecation note warns that
    /// a stale `catch GenerationError.exceededContextWindowSize` silently stops
    /// matching after a rebuild. Depending only on "it threw" keeps this correct
    /// across both SDKs; the router treats every throw the same way.
    @available(iOS 26.0, *)
    private static func text(
        from session: LanguageModelSession,
        input: String
    ) async throws -> String {
        let response: String
        do {
            response = try await session.respond(to: input).content
        } catch {
            throw LLMError.transport(String(describing: error))
        }

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMError.emptyResponse }
        return trimmed
    }
}
#endif
