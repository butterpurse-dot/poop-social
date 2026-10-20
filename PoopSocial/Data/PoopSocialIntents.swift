import Foundation
import SwiftData
import SwiftUI
import CoreSpotlight

// MARK: - The app graph, reachable from outside the view hierarchy
//
// App Intents do not run inside a SwiftUI view, so they cannot use
// `@Environment`. They need a way to reach the same container and `Store` the UI
// uses. This is that seam — one place, created once, shared.
//
// It is deliberately tiny. Everything it owns is elsewhere; it only makes those
// things findable from an intent.
@MainActor
final class AppGraph {

    static let shared = AppGraph()

    private(set) var container: ModelContainer?
    private(set) var store: Store?

    private init() {}

    /// Called once from the app's `init`, right after the container exists.
    ///
    /// Not a computed property on purpose: building a second `ModelContainer`
    /// here would open a second store file and the intent's writes would land
    /// somewhere the UI never reads.
    func adopt(container: ModelContainer, store: Store) {
        self.container = container
        self.store = store
    }
}

#if canImport(AppIntents)
import AppIntents

// MARK: - Entities: what Siri can *talk about*
//
// An `AppEntity` is a small, stable projection of a thing in the app — an
// identifier plus enough presentation data for the system to display it. Note
// what these deliberately do NOT carry: no `Bathroom` SwiftData object, no
// relationship graph, no mutable state. The entity is a boundary object across
// which the system can pass a *reference*, and the query resolves that reference
// back to the real model when it is needed.
//
// That boundary is why the entity can be `Sendable` and why indexing one does
// not drag the whole object graph into Spotlight.

/// A bathroom, as Siri sees it.
///
/// `IndexedEntity` (which is what contributes the entity to Spotlight's semantic
/// index so vague descriptions like "that clean place near work" can resolve) is
/// iOS 18+, while this app deploys to iOS 17. The conformance is therefore
/// declared in an extension behind an `#available` gate below, rather than on
/// the type itself — otherwise the whole file would fail to compile on iOS 17.
struct BathroomEntity: AppEntity {

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Bathroom",
        numericFormat: "\(placeholder: .int) bathrooms"
    )

    static let defaultQuery = BathroomEntityQuery()

    /// The SwiftData identifier, as a string. Stable and scoped — this is what
    /// the query resolves.
    let id: String
    let name: String
    let address: String
    /// 0–5. Shown as a subtitle so Siri's answer is useful without opening the app.
    let cleanliness: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: address.isEmpty
                ? "\(cleanLabel)"
                : "\(cleanLabel) · \(address)",
            image: .init(systemName: "toilet")
        )
    }

    private var cleanLabel: String {
        if cleanliness == 0 { return "Untested" }
        if cleanliness >= 4.5 { return "Surgical" }
        if cleanliness >= 3.5 { return "Fresh" }
        if cleanliness >= 2.5 { return "Passable" }
        if cleanliness >= 1.5 { return "Rough" }
        return "Biohazard"
    }

    /// Project a model onto the entity.
    ///
    /// The only place `Bathroom` is allowed to become system-visible, so the
    /// projection is defined once and cannot drift between call sites.
    init(_ bathroom: Bathroom) {
        self.id = bathroom.id.uuidString
        self.name = bathroom.name
        self.address = bathroom.address
        self.cleanliness = bathroom.cleanlinessScore
    }

    init(id: String, name: String, address: String, cleanliness: Double) {
        self.id = id
        self.name = name
        self.address = address
        self.cleanliness = cleanliness
    }
}

/// Resolves `BathroomEntity` references back to real bathrooms.
///
/// Conforms to `EntityStringQuery` (as well as the plain `EntityQuery`) because
/// people describe bathrooms by *name* — "the one at the gas station" — and
/// arbitrary string matching is exactly what that interface is for.
struct BathroomEntityQuery: EntityStringQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [BathroomEntity] {
        guard let context = AppGraph.shared.container?.mainContext else { return [] }
        let wanted = Set(identifiers.compactMap(UUID.init(uuidString:)))
        let all = (try? context.fetch(FetchDescriptor<Bathroom>())) ?? []
        return all.filter { wanted.contains($0.id) }.map(BathroomEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [BathroomEntity] {
        guard let context = AppGraph.shared.container?.mainContext else { return [] }
        let all = (try? context.fetch(FetchDescriptor<Bathroom>())) ?? []
        // `localizedStandardContains` is the idiomatic, case- and
        // diacritic-insensitive match, and it is what Apple's own sample uses.
        return all
            .filter {
                $0.name.localizedStandardContains(string)
                    || $0.address.localizedStandardContains(string)
            }
            .map(BathroomEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [BathroomEntity] {
        guard let context = AppGraph.shared.container?.mainContext else { return [] }
        let all = (try? context.fetch(FetchDescriptor<Bathroom>())) ?? []
        // Most-reviewed first: the ones a person is most likely to mean.
        return all
            .sorted { $0.reviewCount > $1.reviewCount }
            .prefix(10)
            .map(BathroomEntity.init)
    }
}

// MARK: - Spotlight indexing (iOS 18+)
//
// `IndexedEntity` is what puts a bathroom into the Spotlight semantic index, so
// Apple Intelligence can find it from a *description* rather than an exact name
// — "the clean one at the library" — and attribute the answer back to this app.
//
// Guarded by compiler version, not just availability. `IndexedEntity` does not
// exist in the iOS 17 App Intents SDK at all, and the framework *is* present on
// iOS 17 — so `canImport(AppIntents)` is true while the symbol is missing, and
// an `@available` annotation does not hide a missing type from the compiler.
// `#if compiler(>=6.0)` is the honest discriminator: Swift 6 ships with Xcode
// 16, which is the first toolchain with the iOS 18 SDK that declares it.
//
// `indexingKey` marks the properties worth searching; it is deliberately just
// the two a person would actually say out loud.
#if compiler(>=6.0)
@available(iOS 18.0, *)
extension BathroomEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.title = name
        attributes.contentDescription = address
        attributes.keywords = ["bathroom", "restroom", "toilet", "loo"]
        return attributes
    }
}
#endif

// MARK: - Enums: what Siri can *choose between*

/// The verdict, as an `AppEnum` so Siri can resolve "that place was great"
/// without anyone writing a phrase list.
enum VerdictChoice: String, AppEnum {
    case satisfying
    case survivable
    case unsatisfying

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Verdict")

    static let caseDisplayRepresentations: [VerdictChoice: DisplayRepresentation] = [
        .satisfying:   DisplayRepresentation(title: "Satisfying", image: .init(systemName: "hand.thumbsup.fill")),
        .survivable:   DisplayRepresentation(title: "Survivable", image: .init(systemName: "equal.circle.fill")),
        .unsatisfying: DisplayRepresentation(title: "Regret", image: .init(systemName: "hand.thumbsdown.fill")),
    ]

    /// Map to the app's own type. One place, so the two cannot drift.
    ///
    /// Note the deliberate mismatch: Siri's word is "regret" (what a person
    /// would actually say) and the model's case is `.unsatisfying` (what the
    /// schema already calls it). This mapping is exactly why the mapping lives
    /// in one place.
    var verdict: Verdict {
        switch self {
        case .satisfying:   return .satisfying
        case .survivable:   return .neutral
        case .unsatisfying: return .unsatisfying
        }
    }
}

// MARK: - Intents: what Siri can *do*
//
// These map onto `Store` methods that already exist and are already tested. The
// intent layer adds no business logic — it translates a spoken request into the
// same call the UI makes, which is what keeps Siri from becoming a second,
// subtly different write path.

/// "Hey Siri, rate the bathroom at the library."
struct RateBathroomIntent: AppIntent {

    static let title: LocalizedStringResource = "Rate a Bathroom"

    static let description = IntentDescription(
        "Record how a bathroom visit went, with an optional note.",
        categoryName: "Bathrooms"
    )

    /// Confirmation is on by default; a review is a write, so the user should
    /// see what is about to be saved. (This is also an App Review expectation
    /// for intents that create content.)
    static var parameterSummary: some ParameterSummary {
        Summary("Rate \(\.$bathroom) as \(\.$verdict)") {
            \.$note
        }
    }

    @Parameter(title: "Bathroom")
    var bathroom: BathroomEntity

    @Parameter(title: "Verdict")
    var verdict: VerdictChoice

    @Parameter(title: "Note", description: "Optional. A few words about the visit.")
    var note: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<BathroomEntity> {
        guard let store = AppGraph.shared.store else {
            throw LLMIntentError.appNotReady
        }
        guard let context = AppGraph.shared.container?.mainContext,
              let uuid = UUID(uuidString: bathroom.id),
              let model = (try? context.fetch(FetchDescriptor<Bathroom>()))?.first(where: { $0.id == uuid })
        else {
            throw LLMIntentError.bathroomNotFound
        }

        // The note goes through the same moderation choke point as every other
        // piece of user content. Siri is not a bypass.
        let raw = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = Safety.moderator.sanitize(raw)

        store.submitReview(
            bathroom: model,
            author: store.me(),
            mood: mood(for: verdict),
            cleanliness: cleanliness(for: verdict),
            waitMinutes: 0,
            verdict: verdict.verdict,
            note: safe,
            joke: "",
            emoji: "🚽",
            shareToFeed: false
        )

        // `ProvidesDialog` with full + supporting strings: Siri reads the full
        // one on voice-only devices like AirPods, where there is no screen to
        // show the shorter version. The full string has to stand alone.
        return .result(
            value: BathroomEntity(model),
            dialog: IntentDialog(
                full: "Logged \(verdict.rawValue) for \(model.name). Hope the next stop treats you better.",
                supporting: "Saved your \(verdict.rawValue) rating."
            )
        )
    }

    /// Cleanliness is bucketed from the verdict rather than asked separately —
    /// one spoken answer should be enough. The user can refine it in the app.
    private func cleanliness(for verdict: VerdictChoice) -> Int {
        switch verdict {
        case .satisfying:   return 4
        case .survivable:   return 3
        case .unsatisfying: return 2
        }
    }

    private func mood(for verdict: VerdictChoice) -> Mood {
        switch verdict {
        case .satisfying:   return .good
        case .survivable:   return .survivable
        case .unsatisfying: return .rough
        }
    }
}

/// "Hey Siri, add a bathroom called the Marigold Cafe."
struct AddBathroomIntent: AppIntent {

    static let title: LocalizedStringResource = "Add a Bathroom"

    static let description = IntentDescription(
        "Save a new bathroom so you and your crew can rate it later.",
        categoryName: "Bathrooms"
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name)") {
            \.$address
        }
    }

    @Parameter(title: "Name", description: "What you call this place.")
    var name: String

    @Parameter(title: "Address", description: "Optional. Where it is.")
    var address: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<BathroomEntity> {
        guard let store = AppGraph.shared.store else {
            throw LLMIntentError.appNotReady
        }

        let cleanName = Safety.moderator
            .sanitize(name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw LLMIntentError.emptyName
        }

        let model = store.addBathroom(
            name: cleanName,
            address: Safety.moderator.sanitize(address ?? ""),
            // No location permission is requested from an intent. A bathroom
            // added by voice has no coordinates until it is opened in the app
            // and located there — which is the honest behaviour, and keeps the
            // location permission tied to a visible, in-app action.
            latitude: 0,
            longitude: 0,
            kind: .publicRestroom,
            amenities: [],
            addedBy: store.me()
        )

        return .result(
            value: BathroomEntity(model),
            dialog: IntentDialog(
                full: "Added \(model.name). Rate it whenever you're ready.",
                supporting: "Added \(model.name)."
            )
        )
    }
}

// MARK: - Shortcuts: the phrases that make the intents reachable
//
// `AppShortcutsProvider` is what lets these work **without the user building a
// shortcut first**. Apple recommends keeping this list short and focused on the
// app's real verbs, which is two here.

struct PoopSocialShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RateBathroomIntent(),
            phrases: [
                "Rate a bathroom in \(.applicationName)",
                "Log a bathroom visit in \(.applicationName)",
            ],
            shortTitle: "Rate a bathroom",
            systemImageName: "star.bubble.fill"
        )

        AppShortcut(
            intent: AddBathroomIntent(),
            phrases: [
                "Add a bathroom in \(.applicationName)",
                "New bathroom in \(.applicationName)",
            ],
            shortTitle: "Add a bathroom",
            systemImageName: "plus.circle.fill"
        )
    }
}

/// Errors that can surface to Siri. `CustomLocalizedStringResourceConvertible`
/// is what makes them read as sentences instead of error codes.
enum LLMIntentError: Error, CustomLocalizedStringResourceConvertible {
    case appNotReady
    case bathroomNotFound
    case emptyName

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .appNotReady:
            // No `\(.applicationName)` here: that interpolation needs the
            // contextual type that only `IntentDialog` supplies, and this is a
            // bare `LocalizedStringResource`. Plain text is simpler and correct.
            return "Open the app once so it can get ready."
        case .bathroomNotFound:
            return "I couldn't find that bathroom. Try adding it first."
        case .emptyName:
            return "I need a name for that bathroom."
        }
    }
}

#endif
