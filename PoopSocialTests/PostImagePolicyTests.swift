import XCTest
import SwiftData

/// The no-images policy, proven **structurally** rather than promised.
///
/// ## Why this is a separate test from the UI one
///
/// `EndToEndUITests.testNoImageInputExistsStructurally` proves no image *control*
/// is reachable in the composer. That is necessary but not sufficient: a UI test
/// can only see what the current build's view tree happens to render. If someone
/// later added an `imageData: Data?` field to `Post`, nothing would catch the
/// *model* gaining the capacity, and an image feature could ship without the
/// policy being consciously revisited.
///
/// This test asserts the capacity is absent at the **type** level, which is the
/// claim the product actually makes: "photos and videos are blocked at the
/// engine level."
///
/// ## Why this reads the SwiftData schema
///
/// The obvious approach — `Mirror(reflecting: Post())` — does not work: `Post`
/// is a `@Model`, so constructing one requires a live `ModelContainer` and the
/// test process dies with
///
///     Fatal error: failed to find a currently active container for Post
///
/// Reading `Schema([Post.self])` is both *possible* without a container and
/// *more accurate* for this claim: the schema is precisely what the store is
/// able to persist. A field the schema does not carry cannot hold an image,
/// which is the assertion being made.
final class PostImagePolicyTests: XCTestCase {

    /// Property names that would indicate stored media, matched
    /// case-insensitively as substrings so `imageData`, `photoURL`,
    /// `videoAttachment`, `thumbnailBytes` and similar all trip it.
    private let bannedFragments = [
        "image", "photo", "video", "picture", "media", "attach",
        "thumbnail", "jpeg", "png", "heic", "movie", "clip", "camera",
    ]

    /// Types that could carry bytes. If a schema property is one of these, that
    /// is a real path for an image to reach storage.
    private let byteCarryingTypes = [
        "Data", "NSData", "URL", "UIImage", "CGImage", "CIImage",
        "AVAsset", "AVURLAsset", "PHAsset",
    ]

    /// Every attribute the store could persist for `Post`.
    private var postAttributes: [(name: String, typeName: String)] {
        let schema = Schema([Post.self])
        return schema.entities
            .filter { $0.name == "Post" }
            .flatMap { $0.attributes }
            .map { ($0.name, String(describing: $0.valueType)) }
    }

    func testSchemaActuallyExposesAttributes() throws {
        // Guard against the whole file passing vacuously: if `Schema([Post.self])`
        // returned nothing, every assertion below would trivially succeed and
        // the suite would be worthless.
        let attributes = postAttributes
        XCTAssertFalse(attributes.isEmpty,
                       "Schema([Post.self]) exposed no attributes — the checks "
                       + "in this file would pass vacuously and must not be trusted")
        // Sanity: a known-real field, so we know we are looking at the right entity.
        XCTAssertTrue(attributes.contains { $0.name == "body" },
                      "schema has no 'body' attribute — wrong entity; got "
                      + "\(attributes.map(\.name))")
    }

    func testPostHasNoImageOrVideoStorage() throws {
        let attributes = postAttributes
        XCTAssertFalse(attributes.isEmpty, "no Post attributes to inspect")

        for attribute in attributes {
            let lower = attribute.name.lowercased()
            for fragment in bannedFragments where lower.contains(fragment) {
                XCTFail("Post.\(attribute.name) looks like media storage "
                        + "('\(fragment)'). The no-images policy is structural: "
                        + "if this field is deliberate, remove the fragment from "
                        + "bannedFragments AND explain why — do not delete this test.")
            }
        }
    }

    /// The stronger form: no persisted `Post` attribute is of a byte-carrying
    /// type, whatever it is named. Catches a field named innocuously (`payload`,
    /// `blob`) that is nevertheless capable of holding an image.
    func testPostHasNoByteCarryingAttributes() throws {
        let attributes = postAttributes
        XCTAssertFalse(attributes.isEmpty, "no Post attributes to inspect")

        for (name, typeName) in attributes {
            let inner = typeName
                .replacingOccurrences(of: "Optional<", with: "")
                .replacingOccurrences(of: "Array<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .trimmingCharacters(in: .whitespaces)

            for byteType in byteCarryingTypes
            where inner == byteType || inner.hasSuffix("." + byteType) {
                XCTFail("Post.\(name) persists as \(typeName) — a field that can "
                        + "carry binary payload could carry an image. The product "
                        + "stores text, emoji and references only.")
            }
        }
    }

    /// `PostSurface` must not gain a media case. A `.photo` or `.video` surface
    /// would bypass every other check, since the surface decides what the
    /// composer renders.
    ///
    /// There is no `allCases` to iterate: `PostSurface` is a plain `String`-backed
    /// enum with no `CaseIterable`. Since the Reels removal it has exactly one
    /// case, `.drop`. What this checks is the two things that matter: a media
    /// case cannot be *decoded into*, and unknown persisted values still fall
    /// back rather than throwing — the hardening added when Reels was removed,
    /// so a stale value from an older build cannot brick the feed.
    func testPostSurfaceRejectsMediaAndFallsBackSafely() throws {
        for media in ["photo", "video", "image", "reels", "gallery"] {
            let data = Data("\"\(media)\"".utf8)
            let decoded = try JSONDecoder().decode(PostSurface.self, from: data)
            XCTAssertEqual(decoded, .drop,
                           "PostSurface decoded '\(media)' to '\(decoded.rawValue)'. "
                           + "Only 'drop' may exist: a media surface would bypass "
                           + "the composer's structural block.")
        }

        // The one real case round-trips.
        XCTAssertEqual(
            try JSONDecoder().decode(PostSurface.self, from: Data("\"drop\"".utf8)),
            .drop
        )
    }

    /// The same claim for the other media-capable types in the graph. A `Review`
    /// or a `Bathroom` gaining an image field would be just as much a breach as
    /// `Post` doing so.
    func testNoPersistedTypeCarriesMedia() throws {
        let schema = Schema([Post.self, Review.self, Bathroom.self, Profile.self])

        var inspected = 0
        for entity in schema.entities {
            for attribute in entity.attributes {
                inspected += 1
                let lower = attribute.name.lowercased()
                for fragment in bannedFragments where lower.contains(fragment) {
                    XCTFail("\(entity.name).\(attribute.name) looks like media "
                            + "storage ('\(fragment)'). The policy covers the "
                            + "whole graph, not just Post.")
                }
            }
        }
        XCTAssertGreaterThan(inspected, 20,
                             "only \(inspected) attributes inspected — the schema "
                             + "walk is not covering the graph, so this proves little")
    }

    /// A control: prove the fragment-matching logic actually *can* detect a
    /// violation, so the passing results above are meaningful rather than an
    /// artefact of the matcher never firing.
    func testDetectionHarnessActuallyWorks() throws {
        let knownBad = ["imageData", "photoCount", "videoURL", "thumbnailBytes"]
        for name in knownBad {
            let flagged = bannedFragments.contains {
                name.lowercased().contains($0)
            }
            XCTAssertTrue(flagged,
                          "the media-detection matcher failed to flag '\(name)', "
                          + "so the schema assertions above prove nothing")
        }

        // And a negative control: real field names must NOT be flagged, or the
        // test would fail on a correct implementation.
        for name in ["body", "emoji", "joke", "vibe", "verdict", "backdrop"] {
            let flagged = bannedFragments.contains {
                name.lowercased().contains($0)
            }
            XCTAssertFalse(flagged,
                           "'\(name)' is a legitimate Post field but was flagged "
                           + "as media — the matcher is too broad to be trusted")
        }
    }
}
