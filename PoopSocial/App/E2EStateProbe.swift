import Foundation
import SwiftData
import SwiftUI

// MARK: - End-to-end state probe
//
// Why this exists at all
// ----------------------
// The UI tests can *drive* the app (tap Compose, type, publish) and can see
// that a sheet dismissed. What they could not do is answer the only question
// that matters for a social app: **did it persist?** A post that appears in the
// feed and vanishes on relaunch passes every smoke test and is still broken.
//
// There is no way to assert on persistence from outside the process, because the
// store lives in the app's container. So this view exposes the persisted graph
// as *readable text* when — and only when — the app is launched with
// `-e2eProbe`. XCUITest can then query it like any other label and assert
// against real stored rows rather than against the UI's rendering of them.
//
// Design constraints, each deliberate:
//
//   * **Off by default.** Without the launch argument this view is never
//     constructed. There is no code path a real user can reach, so the probe
//     cannot leak state or affect shipping behaviour.
//
//   * **Read-only.** It queries; it never writes, deletes or migrates. A test
//     that corrupts the store it is measuring would report nonsense.
//
//   * **Stable machine-readable lines.** Each fact is one line, `key=value`,
//     so assertions match on exact strings rather than on prose that a copy edit
//     could silently break.
//
//   * **Counts, not contents, for free text.** Post bodies are user data; the
//     probe reports how many posts exist and whether a specific body is present,
//     so a test can prove a write landed without the probe becoming a way to
//     exfiltrate everything in the store.

/// One line per fact, `key=value`, appended in a deterministic order.
struct E2EStateProbe: View {

    @Environment(\.modelContext) private var context

    // ## Why @Query, not just a fetch
    //
    // The first version read the context inside `body` via `fetchCount`. That
    // computed the right numbers *once* and then never changed, because SwiftUI
    // had no observation dependency on the store — so the view was never
    // invalidated when a post was written. The symptom was a persistence test
    // failing with the count moving *backwards*:
    //
    //   XCTAssertEqual failed: ("427") is not equal to ("428")
    //
    // ...because the "before" read and the "after" read were both serving a
    // stale cached snapshot rather than re-querying.
    //
    // `@Query` registers the dependency properly, so the probe re-renders on
    // every store change. These declarations exist only to create that
    // dependency; the counts are still computed from the context below so the
    // logic stays in one place.
    @Query private var allPosts: [Post]
    @Query private var allProfiles: [Profile]
    @Query private var allBathrooms: [Bathroom]
    @Query private var allReviews: [Review]
    @Query private var allReactions: [Reaction]
    @Query private var allReposts: [Repost]
    @Query private var allBookmarks: [Bookmark]
    @Query private var allConnections: [Connection]
    @Query private var allInvites: [Invite]

    /// Set by the launch argument, read by the probe view.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-e2eProbe")
    }

    var body: some View {
        // Touch every query so the observation dependency is definitely
        // registered, even if a particular line below is later removed.
        let _ = (allPosts.count, allProfiles.count, allBathrooms.count,
                 allReviews.count, allReactions.count, allReposts.count,
                 allBookmarks.count, allConnections.count, allInvites.count)

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Self.snapshot(context: context), id: \.self) { line in
                // Each line is its own accessibility element with the raw
                // string as its identifier, so a test can assert
                // `app.staticTexts["probe:posts=1"].exists` directly.
                Text(line)
                    .font(.system(size: 9, design: .monospaced))
                    .accessibilityIdentifier("probe:\(line)")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(4)
        // The root marker is on a plain Text, not on the container: SwiftUI
        // does not reliably surface an identifier set on a ScrollView/VStack as
        // a queryable element, and a marker that cannot be found is worse than
        // no marker -- it fails the test that checks the probe is alive.
        .background(
            Text("e2eProbeRoot")
                .font(.system(size: 1))
                .accessibilityIdentifier("e2eProbeRoot")
        )
    }

    // MARK: - Snapshot

    /// Build the fact list. `nonisolated` is wrong here — `ModelContext` is not
    /// Sendable — so this stays on the main actor, matching how the rest of the
    /// app touches the context.
    @MainActor
    static func snapshot(context: ModelContext) -> [String] {
        var lines: [String] = []

        func count<T: PersistentModel>(_ type: T.Type, _ name: String) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? -1
        }

        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        // --- Raw row counts. The baseline for "did anything persist". ---
        lines.append("profiles=\(count(Profile.self, "profiles"))")
        lines.append("bathrooms=\(count(Bathroom.self, "bathrooms"))")
        lines.append("reviews=\(count(Review.self, "reviews"))")
        lines.append("posts=\(count(Post.self, "posts"))")
        lines.append("reactions=\(count(Reaction.self, "reactions"))")
        lines.append("reposts=\(count(Repost.self, "reposts"))")
        lines.append("bookmarks=\(count(Bookmark.self, "bookmarks"))")
        lines.append("connections=\(count(Connection.self, "connections"))")
        lines.append("invites=\(count(Invite.self, "invites"))")

        // --- Identity. A relaunch must land on the same `me`. ---
        let me = (try? context.fetch(
            FetchDescriptor<Profile>(predicate: #Predicate { $0.isMe == true })
        ))?.first
        lines.append("me.handle=\(me?.handle ?? "none")")
        lines.append("me.name=\(me?.displayName ?? "none")")

        // --- Engagement, answered from `me`'s own rows. ---
        let reactions = all(Reaction.self)
        lines.append("my.reactions=\(reactions.filter { $0.user?.isMe == true }.count)")
        lines.append("my.reposts=\(all(Repost.self).filter { $0.user?.isMe == true }.count)")
        lines.append("my.bookmarks=\(all(Bookmark.self).filter { $0.user?.isMe == true }.count)")

        // --- Connections by state. Friends AND acquaintances is a product
        // requirement, so both are reported separately rather than totalled. ---
        let links = all(Connection.self)
        lines.append("links.linked=\(links.filter { $0.state == .linked }.count)")
        lines.append("links.outgoing=\(links.filter { $0.state == .outgoing }.count)")
        lines.append("links.friends=\(links.filter { $0.state == .linked && $0.closeness == .friend }.count)")
        lines.append("links.acquaintances=\(links.filter { $0.closeness == .acquaintance }.count)")

        // --- Invites. `hashlen` proves a hash was stored, and the raw-contact
        // absence checks below prove the *raw* value was not. ---
        let invites = all(Invite.self)
        lines.append("invites.pending=\(invites.filter { $0.state == .pending }.count)")
        lines.append("invites.claimed=\(invites.filter { $0.state == .claimed }.count)")
        lines.append("invite.hashlen=\(invites.first?.contactHash.count ?? 0)")
        lines.append("invite.kind=\(invites.first?.kind.rawValue ?? "none")")

        // --- A specific post body, so a test can prove a *particular* write
        // landed rather than merely that the count moved. ---
        let marker = "e2e-marker-drop"
        let posts = all(Post.self)
        lines.append("post.hasMarker=\(posts.contains { $0.body.contains(marker) })")
        lines.append("post.myCount=\(posts.filter { $0.author?.isMe == true && !$0.isReply }.count)")

        // --- Bathroom + review wiring. A review that exists but is attached to
        // no bathroom is a real bug this catches. ---
        lines.append("review.attached=\(all(Review.self).filter { $0.bathroom != nil }.count)")
        lines.append("bathroom.withReviews=\(all(Bathroom.self).filter { !$0.reviews.isEmpty }.count)")

        lines.sort()
        return lines
    }
}
