import XCTest

/// Unit coverage for the content-safety choke point.
///
/// The moderator is pure Swift, so `ContentModerator.swift` is compiled
/// straight into this bundle — no host app, no `@testable import`. That keeps
/// these tests dependency-free and running in milliseconds.
final class ContentModeratorTests: XCTestCase {

    private let moderator = LocalModerator()

    // MARK: - Structural: images are unrepresentable

    /// `MediaKind` must never gain an image case. If someone adds one, this
    /// fails and the no-photos promise gets re-examined rather than silently
    /// broken.
    func testMediaKindHasNoImageCase() {
        let cases = MediaKind.allCases.map(\.rawValue).map { $0.lowercased() }
        for forbidden in ["image", "photo", "video", "picture", "jpeg", "png"] {
            XCTAssertFalse(
                cases.contains(forbidden),
                "MediaKind must not contain an image-like case (\(forbidden))"
            )
        }
        XCTAssertEqual(MediaKind.allCases.count, 3, "unexpected new media kind — review the no-photos rule")
    }

    /// Every media kind is allowed *because* none of them can carry an image.
    func testAllMediaKindsAreTextualAndAllowed() {
        for kind in MediaKind.allCases {
            XCTAssertTrue(moderator.validateMedia(kind).isAllowed,
                          "\(kind.rawValue) should be allowed")
        }
    }

    // MARK: - Emoji palette

    func testApprovedEmojiPass() {
        for emoji in LocalModerator.approvedEmoji {
            XCTAssertTrue(moderator.validateEmoji(emoji).isAllowed,
                          "approved emoji \(emoji) was blocked")
        }
    }

    func testUnapprovedEmojiIsBlocked() {
        // Not in the curated palette.
        let verdict = moderator.validateEmoji("🍆")
        XCTAssertFalse(verdict.isAllowed)
        XCTAssertEqual(verdict.reason, .noImagesAllowed)
    }

    /// The palette must not contain anything graphic.
    func testPaletteContainsNoGraphicEmoji() {
        let graphic = ["💩", "🍆", "🍑", "🩸", "🧠", "🫀"]
        for bad in graphic {
            XCTAssertFalse(LocalModerator.approvedEmoji.contains(bad),
                           "graphic emoji \(bad) must not be in the approved palette")
        }
    }

    // MARK: - Text validation

    func testEmptyTextIsBlocked() {
        for input in ["", "   ", "\n\n", "\t "] {
            let verdict = moderator.validate(text: input)
            XCTAssertFalse(verdict.isAllowed, "\(input.debugDescription) should be blocked")
            XCTAssertEqual(verdict.reason, .empty)
        }
    }

    func testTooLongTextIsBlocked() {
        let long = String(repeating: "a", count: LocalModerator.maxLength + 1)
        let verdict = moderator.validate(text: long)
        XCTAssertFalse(verdict.isAllowed)
        XCTAssertEqual(verdict.reason, .tooLong)
    }

    func testBoundaryLengthIsAllowed() {
        let exact = String(repeating: "a", count: LocalModerator.maxLength)
        XCTAssertTrue(moderator.validate(text: exact).isAllowed,
                      "text at exactly maxLength must be allowed")
    }

    func testFlaggedTermsAreBlocked() {
        for term in LocalModerator.flaggedTerms {
            let verdict = moderator.validate(text: "hey this has \(term) in it")
            XCTAssertFalse(verdict.isAllowed, "\(term) should be blocked")
            XCTAssertEqual(verdict.reason, .flaggedLanguage)
        }
    }

    func testFlaggedTermsAreCaseInsensitive() {
        XCTAssertEqual(moderator.validate(text: "NSFW").reason, .flaggedLanguage)
        XCTAssertEqual(moderator.validate(text: "NuDe").reason, .flaggedLanguage)
    }

    func testOrdinaryTextIsAllowed() {
        let samples = [
            "this stall has heated seats and I feel seen",
            "paper towel dispenser gave me exactly one square",
            "the hand dryer sounds like a jet engine",
            "rate my throne luck"
        ]
        for s in samples {
            XCTAssertTrue(moderator.validate(text: s).isAllowed, "\(s) should be allowed")
        }
    }

    // MARK: - Sanitize

    func testSanitizeCollapsesNewlinesAndTrims() {
        let messy = "  line one  \n\n   line two  \n"
        XCTAssertEqual(moderator.sanitize(messy), "line one line two")
    }

    func testSanitizeTruncatesWithEllipsis() {
        let long = String(repeating: "x", count: LocalModerator.maxLength + 50)
        let out = moderator.sanitize(long)
        XCTAssertEqual(out.count, LocalModerator.maxLength)
        XCTAssertTrue(out.hasSuffix("…"), "truncated output should end with an ellipsis")
    }

    func testSanitizeShortTextIsUnchanged() {
        XCTAssertEqual(moderator.sanitize("  nice  "), "nice")
    }

    // MARK: - Block reasons are user-facing

    func testEveryBlockReasonHasCopy() {
        let reasons: [BlockReason] = [.noImagesAllowed, .flaggedLanguage, .tooLong, .empty]
        for r in reasons {
            XCTAssertFalse(r.title.isEmpty, "\(r) missing title")
            XCTAssertFalse(r.detail.isEmpty, "\(r) missing detail")
            XCTAssertFalse(r.emoji.isEmpty, "\(r) missing emoji")
        }
    }
}
