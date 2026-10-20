import Foundation
import SwiftData

/// First-launch seed. Gives the app a living world immediately so every
/// surface (feed, reels, map, crew, profile) has something real in it.
enum SeedData {

    private static let seededKey = "poopSocial.seeded.v1"

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        if UserDefaults.standard.bool(forKey: seededKey) { return }

        let existing = (try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0
        guard existing == 0 else {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        seed(context: context)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    @MainActor
    private static func seed(context: ModelContext) {
        let now = Date()

        // MARK: People

        let me = Profile(
            displayName: "New Plotter",
            handle: "newplotter",
            avatarEmoji: "🚽",
            bio: "Still figuring out my throne standards.",
            homeCity: "San Francisco",
            isMe: true
        )

        let maya = Profile(displayName: "Maya", handle: "mayaflush", avatarEmoji: "🌸",
                           bio: "Will review your bathroom before your restaurant.",
                           homeCity: "San Francisco",
                           joinedAt: now.addingTimeInterval(-86400 * 120))
        let dev = Profile(displayName: "Dev", handle: "thronewatcher", avatarEmoji: "🧢",
                          bio: "Bathroom sommelier. Notes: damp, tragic, iconic.",
                          homeCity: "Oakland",
                          joinedAt: now.addingTimeInterval(-86400 * 96))
        let priya = Profile(displayName: "Priya", handle: "priyapott", avatarEmoji: "🪐",
                            bio: "I rate the sink. The toilet is a bonus.",
                            homeCity: "San Francisco",
                            joinedAt: now.addingTimeInterval(-86400 * 71))
        let tom = Profile(displayName: "Tom", handle: "tomsan", avatarEmoji: "🦆",
                          bio: "Hovering is a lifestyle and I'm working on it.",
                          homeCity: "Berkeley",
                          joinedAt: now.addingTimeInterval(-86400 * 55))
        let nour = Profile(displayName: "Nour", handle: "nourclean", avatarEmoji: "🧼",
                           bio: "Hygiene influencer. Yes, that's a thing now.",
                           homeCity: "San Francisco",
                           joinedAt: now.addingTimeInterval(-86400 * 40))
        let jae = Profile(displayName: "Jae", handle: "jaeflush", avatarEmoji: "🎧",
                          bio: "Sound design is 90% of the restroom experience.",
                          homeCity: "San Jose",
                          joinedAt: now.addingTimeInterval(-86400 * 28))
        let lila = Profile(displayName: "Lila", handle: "lilaloop", avatarEmoji: "🍭",
                           bio: "Collecting clean bathrooms like trading cards.",
                           homeCity: "San Francisco",
                           joinedAt: now.addingTimeInterval(-86400 * 19))
        let omar = Profile(displayName: "Omar", handle: "omario", avatarEmoji: "🧃",
                           bio: "New in town. Please recommend a good stall.",
                           homeCity: "San Francisco",
                           joinedAt: now.addingTimeInterval(-86400 * 6))

        let everyone = [me, maya, dev, priya, tom, nour, jae, lila, omar]
        everyone.forEach { context.insert($0) }

        // MARK: Connections

        func link(_ a: Profile, _ b: Profile, _ state: LinkState, _ closeness: Closeness, daysAgo: Int) {
            let c = Connection(
                state: state,
                closeness: closeness,
                createdAt: now.addingTimeInterval(-86400 * Double(daysAgo))
            )
            context.insert(c)
            c.from = a
            c.to = b
        }

        link(me, maya, .linked, .bestie, daysAgo: 60)
        link(me, dev, .linked, .friend, daysAgo: 44)
        link(me, priya, .linked, .friend, daysAgo: 30)
        link(me, tom, .linked, .acquaintance, daysAgo: 18)
        link(me, nour, .linked, .acquaintance, daysAgo: 9)
        link(jae, me, .outgoing, .acquaintance, daysAgo: 3)      // incoming request
        link(me, lila, .outgoing, .acquaintance, daysAgo: 2)     // awaiting accept
        link(maya, priya, .linked, .friend, daysAgo: 50)

        // MARK: Bathrooms

        let mint = Bathroom(name: "The Mint Throne", address: "170 O'Farrell St, Union Square",
                            latitude: 37.7879, longitude: -122.4075, kind: .mall,
                            amenities: [.free, .accessible, .soap, .paper, .wellLit, .babyChanging],
                            addedByName: "Maya", createdAt: now.addingTimeInterval(-86400 * 40))
        let lumiere = Bathroom(name: "Café Lumière", address: "1 Embarcadero Center",
                               latitude: 37.7936, longitude: -122.3965, kind: .cafe,
                               amenities: [.soap, .paper, .handDryer, .privateStall],
                               addedByName: "Priya", createdAt: now.addingTimeInterval(-86400 * 33))
        let restStop = Bathroom(name: "Golden Gate Rest Stop", address: "Sloat Blvd & Great Hwy",
                                latitude: 37.8078, longitude: -122.4750, kind: .park,
                                amenities: [.free, .open24h],
                                addedByName: "Tom", createdAt: now.addingTimeInterval(-86400 * 27))
        let mission = Bathroom(name: "Mission Clean Co.", address: "3150 18th St, Mission",
                               latitude: 37.7620, longitude: -122.4120, kind: .publicRestroom,
                               amenities: [.free, .accessible, .soap, .paper, .staffed, .wellLit],
                               addedByName: "Nour", createdAt: now.addingTimeInterval(-86400 * 21))
        let meridian = Bathroom(name: "Hotel Meridian Lobby", address: "88 Sutter St",
                                latitude: 37.7897, longitude: -122.4009, kind: .hotel,
                                amenities: [.free, .accessible, .soap, .paper, .handDryer, .privateStall, .wellLit],
                                addedByName: "Dev", createdAt: now.addingTimeInterval(-86400 * 16))
        let transbay = Bathroom(name: "Transbay Terminal", address: "425 Mission St",
                                latitude: 37.7896, longitude: -122.3957, kind: .transit,
                                amenities: [.free, .accessible, .open24h, .soap],
                                addedByName: "Jae", createdAt: now.addingTimeInterval(-86400 * 12))
        let library = Bathroom(name: "The Library Vault", address: "100 Larkin St, Civic Center",
                               latitude: 37.7793, longitude: -122.4158, kind: .library,
                               amenities: [.free, .accessible, .soap, .paper, .wellLit, .privateStall],
                               addedByName: "Lila", createdAt: now.addingTimeInterval(-86400 * 8))
        let rooftop = Bathroom(name: "Rooftop Bar 12", address: "12 Mission St",
                               latitude: 37.7750, longitude: -122.4180, kind: .bar,
                               amenities: [.privateStall, .wellLit],
                               addedByName: "Omar", createdAt: now.addingTimeInterval(-86400 * 4))
        let gas = Bathroom(name: "Gas & Go", address: "600 Bryant St",
                           latitude: 37.7710, longitude: -122.4300, kind: .gasStation,
                           amenities: [.free, .open24h],
                           addedByName: "Maya", createdAt: now.addingTimeInterval(-86400 * 2))

        let bathrooms = [mint, lumiere, restStop, mission, meridian, transbay, library, rooftop, gas]
        bathrooms.forEach { context.insert($0) }

        // MARK: Reviews

        func review(_ bathroom: Bathroom, _ author: Profile, _ mood: Mood, clean: Int,
                    wait: Int, _ verdict: Verdict, _ note: String, _ joke: String,
                    _ emoji: String, hoursAgo: Double) {
            let r = Review(
                rating: mood.rawValue,
                cleanliness: clean,
                waitMinutes: wait,
                verdict: verdict,
                note: note,
                joke: joke,
                emoji: emoji,
                createdAt: now.addingTimeInterval(-3600 * hoursAgo)
            )
            context.insert(r)
            r.bathroom = bathroom
            r.author = author
        }

        review(mint, maya, .transcendent, clean: 5, wait: 2, .satisfying,
               "Genuinely the cleanest mall bathroom I've ever met. Attendant nodded at me like a colleague.",
               "That wasn't a bathroom break. That was a factory reset.", "🤩", hoursAgo: 52)
        review(mint, priya, .good, clean: 5, wait: 5, .satisfying,
               "Mirror lighting is unreal. I fixed my hair and my life.",
               "This bathroom is lowkey giving spa energy.", "✨", hoursAgo: 30)
        review(mint, tom, .survivable, clean: 4, wait: 8, .neutral,
               "Solid. Slightly long line but the stall doors actually lock.",
               "It was a bathroom. It did the job.", "😐", hoursAgo: 12)

        review(lumiere, priya, .good, clean: 4, wait: 1, .satisfying,
               "Tiny but spotless. The hand dryer sounds like a jet engine, which is a mood.",
               "Rent free in my head: the hand dryer.", "😌", hoursAgo: 40)
        review(lumiere, dev, .rough, clean: 2, wait: 6, .unsatisfying,
               "Soap dispenser empty at 11am. The plot thickens.",
               "The soap was a rumor.", "😬", hoursAgo: 14)

        review(restStop, tom, .catastrophic, clean: 1, wait: 0, .unsatisfying,
               "I have made a series of decisions and none of them were this one.",
               "That wasn't a restroom. That was a cautionary tale.", "💀", hoursAgo: 61)
        review(restStop, maya, .rough, clean: 2, wait: 0, .unsatisfying,
               "Ocean view is carrying the entire review. Nothing else is helping.",
               "Zero stars. The star is a lie.", "🤢", hoursAgo: 22)

        review(mission, nour, .transcendent, clean: 5, wait: 3, .satisfying,
               "Staffed, stocked, and the mirror has a shelf. This is the blueprint.",
               "That was a full system update. Version 2.0.", "🏆", hoursAgo: 35)
        review(mission, lila, .good, clean: 5, wait: 4, .satisfying,
               "Immaculate. I felt like I should whisper.",
               "My soul did a little stretch.", "🤩", hoursAgo: 18)
        review(mission, dev, .good, clean: 4, wait: 7, .satisfying,
               "Great, but the queue moves like a group project.",
               "The acoustics in there? Concert hall.", "😌", hoursAgo: 5)

        review(meridian, dev, .transcendent, clean: 5, wait: 0, .satisfying,
               "Lobby bathrooms are the cheat code. Marble. Actual marble.",
               "Walked in a mortal. Walked out a legend.", "🤩", hoursAgo: 44)
        review(meridian, maya, .good, clean: 5, wait: 1, .satisfying,
               "Impeccable. I pretended I was a guest. Nobody stopped me.",
               "No cap, that was a top-tier throne.", "✨", hoursAgo: 20)

        review(transbay, jae, .survivable, clean: 3, wait: 9, .neutral,
               "It exists. The line is a social experiment.",
               "It's giving 'cleaned once, in 2011'.", "🫥", hoursAgo: 26)
        review(transbay, tom, .rough, clean: 2, wait: 12, .unsatisfying,
               "The handle had opinions and none of them were flush.",
               "The handle had opinions and none of them were 'flush'.", "😬", hoursAgo: 9)

        review(library, lila, .good, clean: 5, wait: 0, .satisfying,
               "Silent. Clean. Slightly haunted in a nice way. 10/10.",
               "I'm not saying it was spiritual. I'm saying I saw a light.", "👏", hoursAgo: 31)
        review(library, priya, .survivable, clean: 4, wait: 2, .neutral,
               "Great until the automatic light turned off mid-session.",
               "The stall door didn't latch, and neither did my dignity.", "🫥", hoursAgo: 7)

        review(rooftop, omar, .rough, clean: 2, wait: 14, .unsatisfying,
               "Great view from the line. That's all I can report.",
               "I'm filing a complaint with the universe.", "💀", hoursAgo: 11)

        review(gas, maya, .survivable, clean: 3, wait: 0, .neutral,
               "Surprisingly not a war crime. The key is attached to a hubcap.",
               "Delulu is thinking the soap will appear.", "😅", hoursAgo: 6)

        // MARK: Posts — drops

        @discardableResult
        func drop(_ author: Profile, _ body: String, _ emoji: String, _ joke: String,
                  _ verdict: Verdict, _ bathroom: Bathroom?, hoursAgo: Double,
                  surface: PostSurface = .drop, backdrop: Int = 0, vibe: String = "",
                  parent: Post? = nil) -> Post {
            let p = Post(
                surface: surface,
                body: body,
                emoji: emoji,
                joke: joke,
                verdict: verdict,
                backdrop: backdrop,
                vibe: vibe,
                parentID: parent?.id,
                createdAt: now.addingTimeInterval(-3600 * hoursAgo)
            )
            context.insert(p)
            p.author = author
            p.bathroom = bathroom
            return p
        }

        let d1 = drop(maya, "Found a spot on 4th with actual soap AND a working lock. I'm emotional.",
                      "🧼", "This bathroom is lowkey giving spa energy.", .satisfying, mission, hoursAgo: 1.2)
        let d2 = drop(dev, "The paper towel dispenser made eye contact and chose violence.",
                      "💀", "The paper was decorative. Purely decorative.", .unsatisfying, lumiere, hoursAgo: 2.4)
        let d3 = drop(priya, "Rating the office bathroom: 2/5. The door has a gap. A GAP.",
                      "😬", "It's not a red flag, it's a biohazard sign.", .unsatisfying, nil, hoursAgo: 3.1)
        let d4 = drop(nour, "PSA: twenty seconds of scrubbing is one chorus. Pick a banger and commit.",
                      "🫧", "Twenty seconds. That's one chorus of your favorite song.", .neutral, nil, hoursAgo: 4.0)
        let d5 = drop(tom, "Update: I sat down. Nothing happened. I'm seeking therapy and a better bathroom.",
                      "🫡", "Walked in confident. Left with a character arc.", .neutral, transbay, hoursAgo: 5.5)
        let d6 = drop(jae, "The hand dryer in here has a 3-second delay and a personal vendetta.",
                      "🎧", "Rent free in my head: the hand dryer.", .unsatisfying, transbay, hoursAgo: 6.8)
        let d7 = drop(lila, "Quietest bathroom in the city. I heard my own thoughts. Didn't like them.",
                      "📚", "I'm not saying it was spiritual. I'm saying I saw a light.", .satisfying, library, hoursAgo: 8.2)
        let d8 = drop(omar, "New in town. Which bathroom do I trust first? Be serious.",
                      "🧃", "What's your 'I need a bathroom NOW' route in this city?", .neutral, nil, hoursAgo: 9.0)
        let d9 = drop(maya, "Hotel lobby bathrooms are the cheat code and I will not be gatekeeping.",
                      "🏆", "Walked in a mortal. Walked out a legend.", .satisfying, meridian, hoursAgo: 11.5)
        let d10 = drop(priya, "Would you rather: no soap or no paper? Wrong answers only.",
                       "💬", "Would you rather: no soap or no paper?", .neutral, nil, hoursAgo: 13.0)
        let d11 = drop(dev, "The gas station bathroom had a hubcap key. I respect the engineering.",
                       "🪠", "That place has a whole personality disorder.", .neutral, gas, hoursAgo: 16.0)
        let d12 = drop(nour, "Reminder: the exit handle is the dirtiest thing in the room. Elbow it.",
                       "🛡️", "Elbow the door. It's called range.", .neutral, nil, hoursAgo: 19.0)

        // Threads / replies
        _ = drop(priya, "No soap. Next question.", "🧼", "", .neutral, nil, hoursAgo: 12.6, parent: d10)
        _ = drop(dev, "No paper, obviously. Soap is negotiable. Paper is infrastructure.",
                 "🧻", "", .neutral, nil, hoursAgo: 12.4, parent: d10)
        _ = drop(tom, "Neither. I bring my own kit like a professional.",
                 "🎒", "", .neutral, nil, hoursAgo: 12.1, parent: d10)
        _ = drop(maya, "Start with the library. Then the hotel lobby. Thank me later.",
                 "🗺️", "", .neutral, library, hoursAgo: 8.6, parent: d8)
        _ = drop(nour, "Mission Clean Co. is the blueprint. Staffed and stocked.",
                 "✨", "", .satisfying, mission, hoursAgo: 8.4, parent: d8)

        // My own starter posts
        _ = drop(me, "Just downloaded this. My first act as a citizen is to report that my kitchen sink is not a bathroom.",
                 "🚽", "Based on a true flush.", .neutral, nil, hoursAgo: 0.6)
        _ = drop(me, "Scouting bathrooms this weekend. Taking recommendations and emotional support.",
                 "🫡", "", .neutral, nil, hoursAgo: 0.3)

        // MARK: Posts — reels

        _ = drop(maya, "That wasn't a bathroom break. That was a factory reset.",
                 "🤩", "That wasn't a bathroom break. That was a factory reset.",
                 .satisfying, mint, hoursAgo: 2.0, surface: .reel, backdrop: 0, vibe: "clean-core")

        _ = drop(dev, "The soap was a rumor. The paper was a myth. I remain changed.",
                 "💀", "The soap was a rumor.",
                 .unsatisfying, lumiere, hoursAgo: 4.5, surface: .reel, backdrop: 1, vibe: "tragedy")

        _ = drop(nour, "Twenty seconds. One chorus. That's the whole secret.",
                 "🧼", "Twenty seconds. That's one chorus of your favorite song.",
                 .neutral, mission, hoursAgo: 7.0, surface: .reel, backdrop: 2, vibe: "psa")

        _ = drop(tom, "I've been through things. That bathroom is now one of them.",
                 "😬", "I've been through things. That bathroom is now one of them.",
                 .unsatisfying, restStop, hoursAgo: 10.0, surface: .reel, backdrop: 3, vibe: "trauma")

        _ = drop(jae, "In space, nobody hears the hand dryer either.",
                 "🎧", "In space, nobody hears the hand dryer either.",
                 .neutral, transbay, hoursAgo: 14.0, surface: .reel, backdrop: 4, vibe: "haunted")

        _ = drop(priya, "This bathroom is lowkey giving spa energy. I said what I said.",
                 "✨", "This bathroom is lowkey giving spa energy.",
                 .satisfying, meridian, hoursAgo: 20.0, surface: .reel, backdrop: 0, vibe: "spa")

        // MARK: Reactions

        func react(_ post: Post, _ user: Profile, _ emoji: String, hoursAgo: Double) {
            let r = Reaction(emoji: emoji, createdAt: now.addingTimeInterval(-3600 * hoursAgo))
            context.insert(r)
            r.post = post
            r.user = user
        }

        react(d1, me, "🔥", hoursAgo: 1.0)
        react(d1, priya, "🔥", hoursAgo: 0.9)
        react(d1, nour, "💯", hoursAgo: 0.8)
        react(d1, dev, "🧼", hoursAgo: 0.7)
        react(d1, lila, "✨", hoursAgo: 0.6)

        react(d2, me, "💀", hoursAgo: 2.2)
        react(d2, maya, "💀", hoursAgo: 2.1)
        react(d2, tom, "😭", hoursAgo: 2.0)

        react(d3, priya, "🤝", hoursAgo: 2.9)
        react(d3, nour, "🛡️", hoursAgo: 2.8)

        react(d4, maya, "🧼", hoursAgo: 3.8)
        react(d4, lila, "💯", hoursAgo: 3.7)
        react(d4, me, "🫧", hoursAgo: 3.6)

        react(d5, dev, "😭", hoursAgo: 5.2)
        react(d5, jae, "💀", hoursAgo: 5.1)

        react(d6, me, "🎧", hoursAgo: 6.5)
        react(d6, maya, "😭", hoursAgo: 6.4)

        react(d7, priya, "✨", hoursAgo: 8.0)
        react(d7, nour, "👏", hoursAgo: 7.9)
        react(d7, me, "🤩", hoursAgo: 7.8)

        react(d8, maya, "🗺️", hoursAgo: 8.8)
        react(d8, priya, "🗺️", hoursAgo: 8.7)

        react(d9, priya, "🏆", hoursAgo: 11.0)
        react(d9, nour, "💯", hoursAgo: 10.9)

        react(d10, dev, "💬", hoursAgo: 12.8)
        react(d10, maya, "💬", hoursAgo: 12.7)

        react(d11, tom, "🪠", hoursAgo: 15.5)
        react(d12, maya, "🛡️", hoursAgo: 18.5)
        react(d12, lila, "🧼", hoursAgo: 18.4)

        // Bookmarks for the signed-in user
        for post in [d1, d4, d7] {
            let b = Bookmark(createdAt: now.addingTimeInterval(-3600))
            context.insert(b)
            b.post = post
            b.user = me
        }

        try? context.save()
    }
}
