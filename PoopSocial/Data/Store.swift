import Foundation
import Observation
import SwiftData

/// The one place writes happen.
///
/// Reads go through `@Query` in views (free, live, automatic). Writes funnel
/// through `Store` so behaviour stays consistent and testable. If this ever
/// grows a backend, `Store` is the seam — swap its internals for network calls.
@MainActor
@Observable
final class Store {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Persistence

    func save() {
        do {
            try context.save()
        } catch {
            // Persistence failures here are non-fatal for UX; the in-memory graph
            // is still correct and the next save will retry. Deliberately not an
            // assertion: a failed write should never take the app down mid-tap.
            #if DEBUG
            print("Poop Social save failed:", error)
            #endif
        }
    }

    // MARK: - Lookup

    func me() -> Profile? {
        var descriptor = FetchDescriptor<Profile>(predicate: #Predicate { $0.isMe == true })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func profile(matching handle: String) -> Profile? {
        let needle = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@", with: "")
        guard !needle.isEmpty else { return nil }
        return allProfiles().first {
            $0.handle.lowercased() == needle || $0.displayName.lowercased() == needle
        }
    }

    func allProfiles() -> [Profile] {
        (try? context.fetch(FetchDescriptor<Profile>())) ?? []
    }

    /// `Profile.handle` is `@Attribute(.unique)`, so two people can never share
    /// one. Rather than let a clashing edit blow up a save, nudge the new handle
    /// until it is free (`maya` → `maya2` → `maya3` …).
    func uniqueHandle(_ desired: String, excluding profile: Profile?) -> String {
        let taken = Set(
            allProfiles()
                .filter { $0.id != profile?.id }
                .map { $0.handle.lowercased() }
        )
        guard taken.contains(desired) else { return desired }

        var suffix = 2
        while taken.contains("\(desired)\(suffix)") { suffix += 1 }
        return "\(desired)\(suffix)"
    }

    func allConnections() -> [Connection] {
        (try? context.fetch(FetchDescriptor<Connection>())) ?? []
    }

    // MARK: - Posts

    @discardableResult
    func createPost(
        author: Profile?,
        body: String,
        emoji: String,
        joke: String,
        surface: PostSurface,
        bathroom: Bathroom?,
        verdict: Verdict,
        backdrop: Int = 0,
        vibe: String = "",
        parentID: UUID? = nil
    ) -> Post? {
        let cleanBody = Safety.moderator.sanitize(body)
        let cleanJoke = Safety.moderator.sanitize(joke)

        // Every post must have *some* payload. Emoji always counts.
        if cleanBody.isEmpty && cleanJoke.isEmpty && emoji.isEmpty {
            return nil
        }

        let post = Post(
            surface: surface,
            body: cleanBody,
            emoji: emoji,
            joke: cleanJoke,
            verdict: verdict,
            backdrop: backdrop,
            vibe: vibe,
            parentID: parentID
        )
        context.insert(post)
        post.author = author
        post.bathroom = bathroom
        save()
        return post
    }

    func delete(_ post: Post) {
        context.delete(post)
        save()
    }

    // MARK: - Engagement

    @discardableResult
    func toggleReaction(_ emoji: String, on post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }

        if let existing = post.reactions.first(where: {
            $0.emoji == emoji && $0.user?.id == user.id
        }) {
            context.delete(existing)
            save()
            return false
        }

        let reaction = Reaction(emoji: emoji)
        context.insert(reaction)
        reaction.post = post
        reaction.user = user
        save()
        return true
    }

    func hasReacted(_ emoji: String, on post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }
        return post.reactions.contains { $0.emoji == emoji && $0.user?.id == user.id }
    }

    @discardableResult
    func toggleRepost(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }

        if let existing = post.reposts.first(where: { $0.user?.id == user.id }) {
            context.delete(existing)
            save()
            return false
        }

        let repost = Repost()
        context.insert(repost)
        repost.post = post
        repost.user = user
        save()
        return true
    }

    func hasReposted(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }
        return post.reposts.contains { $0.user?.id == user.id }
    }

    @discardableResult
    func toggleBookmark(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }

        if let existing = post.bookmarks.first(where: { $0.user?.id == user.id }) {
            context.delete(existing)
            save()
            return false
        }

        let bookmark = Bookmark()
        context.insert(bookmark)
        bookmark.post = post
        bookmark.user = user
        save()
        return true
    }

    func hasBookmarked(_ post: Post, by user: Profile?) -> Bool {
        guard let user else { return false }
        return post.bookmarks.contains { $0.user?.id == user.id }
    }

    // MARK: - Connections

    /// Add, request, accept, or remove — one tap, one truth.
    func toggleConnection(with other: Profile) {
        guard let me = me(), other.id != me.id else { return }

        if let link = link(with: other) {
            switch link.state {
            case .incoming:
                link.state = .linked
                Haptics.success()
            case .linked, .outgoing:
                context.delete(link)
            case .none:
                link.state = .outgoing
            }
        } else {
            let link = Connection()
            context.insert(link)
            link.from = me
            link.to = other
            link.state = .outgoing
            link.closeness = .acquaintance
        }
        save()
    }

    func link(with other: Profile) -> Connection? {
        guard let me = me() else { return nil }
        return allConnections().first {
            ($0.from?.id == me.id && $0.to?.id == other.id) ||
            ($0.from?.id == other.id && $0.to?.id == me.id)
        }
    }

    func pendingRequests() -> [Connection] {
        guard let me = me() else { return [] }
        return allConnections().filter { $0.to?.id == me.id && $0.state != .linked }
    }

    func accept(_ connection: Connection) {
        connection.state = .linked
        if connection.closeness < .friend { connection.closeness = .friend }
        Haptics.success()
        save()
    }

    func decline(_ connection: Connection) {
        context.delete(connection)
        save()
    }

    func setCloseness(_ closeness: Closeness, for other: Profile) {
        guard let link = link(with: other) else { return }
        link.state = .linked
        link.closeness = closeness
        Haptics.select()
        save()
    }

    func closeness(to other: Profile) -> Closeness {
        link(with: other)?.closeness ?? .acquaintance
    }

    // MARK: - Bathrooms

    @discardableResult
    func addBathroom(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        kind: BathKind,
        amenities: Set<Amenity>,
        addedBy: Profile?
    ) -> Bathroom {
        let bathroom = Bathroom(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            kind: kind,
            amenities: Array(amenities),
            addedByName: addedBy?.displayName ?? "A stranger"
        )
        context.insert(bathroom)
        save()
        return bathroom
    }

    @discardableResult
    func submitReview(
        bathroom: Bathroom,
        author: Profile?,
        mood: Mood,
        cleanliness: Int,
        waitMinutes: Int,
        verdict: Verdict,
        note: String,
        joke: String,
        emoji: String,
        shareToFeed: Bool
    ) -> Review {
        let review = Review(
            rating: mood.rawValue,
            cleanliness: max(1, min(5, cleanliness)),
            waitMinutes: max(0, waitMinutes),
            verdict: verdict,
            note: Safety.moderator.sanitize(note),
            joke: Safety.moderator.sanitize(joke),
            emoji: emoji
        )
        context.insert(review)
        review.bathroom = bathroom
        review.author = author

        if shareToFeed {
            let post = Post(
                surface: .drop,
                body: review.note,
                emoji: emoji.isEmpty ? mood.emoji : emoji,
                joke: review.joke,
                verdict: verdict,
                vibe: mood.label
            )
            context.insert(post)
            post.author = author
            post.bathroom = bathroom
        }

        save()
        return review
    }

    // MARK: - Profile

    func updateProfile(displayName: String, handle: String, avatarEmoji: String, bio: String, city: String) {
        guard let me = me() else { return }
        let cleanHandle = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        me.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHandle.isEmpty { me.handle = uniqueHandle(cleanHandle, excluding: me) }
        me.avatarEmoji = avatarEmoji
        me.bio = Safety.moderator.sanitize(bio)
        me.homeCity = city
        save()
    }

    // MARK: - Stats

    func myStats() -> (posts: Int, reviews: Int, crew: Int, satisfying: Int, bathrooms: Int) {
        guard let me = me() else { return (0, 0, 0, 0, 0) }
        let crew = me.linkedPeople().count
        let satisfying = me.reviews.filter { $0.verdict == .satisfying }.count
        let bathrooms = Set(me.reviews.compactMap { $0.bathroom?.id }).count
        return (me.posts.filter { !$0.isReply }.count, me.reviews.count, crew, satisfying, bathrooms)
    }
}
