import XCTest
import Foundation

/// Unit coverage for the LLM fallback router.
///
/// The promise is "cloud when possible, local always, automatically" — so these
/// tests are about *ordering*, *failure handling*, and *safety*, not about any
/// particular model's output.
///
/// Everything here uses fake providers. No network, no key, no simulator.
final class LLMRouterTests: XCTestCase {

    // MARK: - Fakes

    /// Records whether it was called, and answers or fails on demand.
    private final class FakeProvider: LLMProvider, @unchecked Sendable {
        let name: String
        let isAvailable: Bool
        private let result: Result<String, Error>
        private(set) var callCount = 0

        init(name: String, available: Bool = true, result: Result<String, Error>) {
            self.name = name
            self.isAvailable = available
            self.result = result
        }

        func complete(task: LLMTask, input: String) async throws -> String {
            callCount += 1
            return try result.get()
        }
    }

    private func router(_ providers: [LLMProvider]) -> LLMRouter {
        LLMRouter(providers: providers, moderator: LocalModerator())
    }

    // MARK: - Happy path

    func testFirstAvailableProviderWins() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .success("A clean, funny line."))
        let local = FakeProvider(name: "On-device", result: .success("local"))

        let result = try await router([cloud, local]).complete(task: .oneLiner, input: "x")

        XCTAssertEqual(result.text, "A clean, funny line.")
        XCTAssertEqual(result.providerName, "Cloud")
        XCTAssertFalse(result.didFallBack, "should not report a fallback when the first provider worked")
        XCTAssertEqual(local.callCount, 0, "the local provider should not be called when cloud succeeds")
    }

    // MARK: - The fallback itself

    func testThrowingProviderFallsBackToNext() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .failure(LLMError.transport("timeout")))
        let local = FakeProvider(name: "On-device", result: .success("local answer"))

        let result = try await router([cloud, local]).complete(task: .hygieneTip, input: "x")

        XCTAssertEqual(result.text, "local answer")
        XCTAssertEqual(result.providerName, "On-device")
        XCTAssertTrue(result.didFallBack, "the caller must be told we fell back")
        XCTAssertEqual(cloud.callCount, 1)
        XCTAssertEqual(local.callCount, 1)
    }

    /// An unavailable provider must be *skipped*, not called and not counted as
    /// a failure. This is the "no API key configured" case.
    func testUnavailableProviderIsSkippedWithoutBeingCalled() async throws {
        let cloud = FakeProvider(name: "Cloud", available: false, result: .success("never"))
        let local = FakeProvider(name: "On-device", result: .success("local answer"))

        let result = try await router([cloud, local]).complete(task: .oneLiner, input: "x")

        XCTAssertEqual(result.text, "local answer")
        XCTAssertEqual(cloud.callCount, 0, "an unavailable provider must not be called")
        XCTAssertEqual(local.callCount, 1)
    }

    /// Empty output is a failure, not a success — otherwise a silent empty
    /// string would render as a blank feature.
    func testEmptyOutputFallsThrough() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .success("   "))
        let local = FakeProvider(name: "On-device", result: .success("real answer"))

        let result = try await router([cloud, local]).complete(task: .oneLiner, input: "x")

        XCTAssertEqual(result.text, "real answer")
        XCTAssertTrue(result.didFallBack)
    }

    /// The moderation rule applies to cloud output too — a crude answer from a
    /// model must not reach the user when a safe local one exists.
    func testFlaggedCloudOutputFallsBackToLocal() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .success("this is nsfw content"))
        let local = FakeProvider(name: "On-device", result: .success("a perfectly civil line"))

        let result = try await router([cloud, local]).complete(task: .oneLiner, input: "x")

        XCTAssertEqual(result.providerName, "On-device")
        XCTAssertEqual(result.text, "a perfectly civil line")
        XCTAssertTrue(result.didFallBack)
    }

    // MARK: - Total failure is explicit

    /// When nothing can answer, that must be an error — never a silent empty
    /// string that the UI would render as a blank card.
    func testAllProvidersFailingThrows() async {
        let cloud = FakeProvider(name: "Cloud", result: .failure(LLMError.transport("down")))
        let local = FakeProvider(name: "On-device", result: .failure(LLMError.emptyResponse))

        do {
            _ = try await router([cloud, local]).complete(task: .oneLiner, input: "x")
            XCTFail("expected noProviderAvailable when every provider fails")
        } catch let error as LLMError {
            XCTAssertEqual(error, .noProviderAvailable)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testNoProvidersAtAllThrows() async {
        do {
            _ = try await router([]).complete(task: .oneLiner, input: "x")
            XCTFail("expected an error with zero providers")
        } catch let error as LLMError {
            XCTAssertEqual(error, .noProviderAvailable)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - Output hygiene

    /// Models wrap output in quotes despite instructions; the router strips them.
    func testSurroundingQuotesAreStripped() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .success("\"A quoted line.\""))
        let result = try await router([cloud]).complete(task: .oneLiner, input: "x")
        XCTAssertEqual(result.text, "A quoted line.")
    }

    /// Emoji from a model are removed; the UI adds its own.
    func testEmojiAreStrippedFromModelOutput() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .success("Clean hands 🧼 save lives"))
        let result = try await router([cloud]).complete(task: .hygieneTip, input: "x")
        XCTAssertFalse(result.text.contains("🧼"))
        XCTAssertTrue(result.text.contains("Clean hands"))
    }

    /// Whitespace noise collapses to single spaces so cards do not reflow oddly.
    func testWhitespaceIsCollapsed() async throws {
        let cloud = FakeProvider(name: "Cloud", result: .success("too    many\n\nspaces"))
        let result = try await router([cloud]).complete(task: .oneLiner, input: "x")
        XCTAssertEqual(result.text, "too many spaces")
    }

    // MARK: - The local provider stands on its own

    func testLocalProviderIsAlwaysAvailable() {
        XCTAssertTrue(LocalLLMProvider().isAvailable,
                      "the local provider must always be available — it is the floor")
    }

    /// Determinism matters: the same input must not flicker between answers.
    func testLocalProviderIsDeterministic() async throws {
        let provider = LocalLLMProvider()
        let a = try await provider.complete(task: .oneLiner, input: "same seed")
        let b = try await provider.complete(task: .oneLiner, input: "same seed")
        XCTAssertEqual(a, b, "local output must be stable for a given input")
    }

    /// And it must actually produce something for every task it claims to serve.
    func testLocalProviderAnswersEveryTask() async throws {
        let provider = LocalLLMProvider()
        for task in LLMTask.allCases {
            let text = try await provider.complete(task: task, input: "a short input")
            XCTAssertFalse(text.isEmpty, "local provider returned nothing for \(task)")
        }
    }

    /// The local provider pulls from the app's own curated corpora, so its
    /// output must pass the app's own content rules.
    func testLocalProviderOutputPassesModeration() async throws {
        let provider = LocalLLMProvider()
        let moderator = LocalModerator()
        for task in LLMTask.allCases {
            let text = try await provider.complete(task: task, input: "seed")
            XCTAssertTrue(
                moderator.validate(text: text).isAllowed,
                "local output for \(task) failed the app's own moderation: \(text)"
            )
        }
    }

    // MARK: - Cloud provider gating

    func testCloudProviderIsUnavailableWithoutAKey() {
        XCTAssertFalse(CloudLLMProvider(apiKey: nil).isAvailable)
        XCTAssertFalse(CloudLLMProvider(apiKey: "").isAvailable)
        XCTAssertFalse(CloudLLMProvider(apiKey: "   ").isAvailable)
        XCTAssertTrue(CloudLLMProvider(apiKey: "sk-test").isAvailable)
    }

    func testCloudProviderThrowsWithoutAKey() async {
        let provider = CloudLLMProvider(apiKey: nil)
        do {
            _ = try await provider.complete(task: .oneLiner, input: "x")
            XCTFail("expected a throw without a key")
        } catch {
            // Any error is acceptable; the router treats all of them as failure.
        }
    }
}
