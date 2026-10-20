import Foundation
import SwiftUI

// MARK: - Original comedy bank
//
// Every line here is written for Poop Social — no lifted movie or TV dialogue.
// They're "in the spirit of" trailer voice-overs, internet slang and group-chat
// banter, which keeps the app legally clean and tonally consistent.

enum LineCategory: String, CaseIterable, Identifiable {
    case victory
    case struggle
    case drama
    case slang
    case hygiene
    case thread

    var id: String { rawValue }

    var label: String {
        switch self {
        case .victory: return "Victory"
        case .struggle: return "Struggle"
        case .drama:   return "Trailer"
        case .slang:   return "Slang"
        case .hygiene: return "Clean"
        case .thread:  return "Threads"
        }
    }

    var emoji: String {
        switch self {
        case .victory: return "🏆"
        case .struggle: return "💀"
        case .drama:   return "🎬"
        case .slang:   return "💅"
        case .hygiene: return "🧼"
        case .thread:  return "💬"
        }
    }

    var tint: Color {
        switch self {
        case .victory: return Theme.lime
        case .struggle: return Theme.danger
        case .drama:   return Theme.grape
        case .slang:   return Theme.bubble
        case .hygiene: return Theme.sky
        case .thread:  return Theme.mint
        }
    }
}

struct PottyLine: Identifiable, Hashable {
    let text: String
    let category: LineCategory
    var id: String { text }
}

enum JokeBank {

    static let all: [PottyLine] = [
        // MARK: Victory
        PottyLine(text: "That wasn't a bathroom break. That was a factory reset.", category: .victory),
        PottyLine(text: "Walked in a mortal. Walked out a legend.", category: .victory),
        PottyLine(text: "Five stars. Would flush again.", category: .victory),
        PottyLine(text: "The acoustics in there? Concert hall.", category: .victory),
        PottyLine(text: "Cleared my cache and my calendar.", category: .victory),
        PottyLine(text: "I feel legally like a new person.", category: .victory),
        PottyLine(text: "That was a full system update. Version 2.0.", category: .victory),
        PottyLine(text: "My soul did a little stretch.", category: .victory),
        PottyLine(text: "Nature called. I answered on the first ring.", category: .victory),
        PottyLine(text: "I'm not saying it was spiritual. I'm saying I saw a light.", category: .victory),
        PottyLine(text: "Left the stall like I'd won an award and forgotten the speech.", category: .victory),
        PottyLine(text: "That was the plot twist nobody asked for and everybody needed.", category: .victory),

        // MARK: Struggle
        PottyLine(text: "The soap was a rumor.", category: .struggle),
        PottyLine(text: "The paper was decorative. Purely decorative.", category: .struggle),
        PottyLine(text: "I've been through things. That bathroom is now one of them.", category: .struggle),
        PottyLine(text: "Walked in confident. Left with a character arc.", category: .struggle),
        PottyLine(text: "The handle had opinions and none of them were 'flush'.", category: .struggle),
        PottyLine(text: "That was a hostage negotiation with my own optimism.", category: .struggle),
        PottyLine(text: "The stall door didn't latch, and neither did my dignity.", category: .struggle),
        PottyLine(text: "Someone before me chose violence.", category: .struggle),
        PottyLine(text: "I have questions. Mostly 'why'.", category: .struggle),
        PottyLine(text: "That wasn't a restroom. That was a cautionary tale.", category: .struggle),
        PottyLine(text: "Zero stars. The star is a lie.", category: .struggle),
        PottyLine(text: "I'm filing a complaint with the universe.", category: .struggle),

        // MARK: Trailer voice
        PottyLine(text: "In a world where the soap is always empty… one person brought hand sanitizer.", category: .drama),
        PottyLine(text: "They said it couldn't get worse. They had never been to the third floor.", category: .drama),
        PottyLine(text: "This summer… the paper towel dispenser fights back.", category: .drama),
        PottyLine(text: "One stall. Two rolls. No witnesses.", category: .drama),
        PottyLine(text: "Some doors you open. Some doors open you.", category: .drama),
        PottyLine(text: "He came for relief. He left with a story.", category: .drama),
        PottyLine(text: "The sequel nobody greenlit: 'Still No Soap'.", category: .drama),
        PottyLine(text: "Rated R for Restroom.", category: .drama),
        PottyLine(text: "Coming soon to a corridor near you.", category: .drama),
        PottyLine(text: "In space, nobody hears the hand dryer either.", category: .drama),
        PottyLine(text: "Based on a true flush.", category: .drama),

        // MARK: Slang
        PottyLine(text: "This bathroom is lowkey giving spa energy.", category: .slang),
        PottyLine(text: "The vibes were immaculate until the dryer started screaming.", category: .slang),
        PottyLine(text: "No cap, that was a top-tier throne.", category: .slang),
        PottyLine(text: "It's giving 'cleaned once, in 2011'.", category: .slang),
        PottyLine(text: "Delulu is thinking the soap will appear.", category: .slang),
        PottyLine(text: "Rent free in my head: the hand dryer.", category: .slang),
        PottyLine(text: "The bathroom understood the assignment. Then it lost the assignment.", category: .slang),
        PottyLine(text: "It's not a red flag, it's a biohazard sign.", category: .slang),
        PottyLine(text: "Mid. Absolutely mid. Maybe lower-mid.", category: .slang),
        PottyLine(text: "That place has a whole personality disorder.", category: .slang),
        PottyLine(text: "That stall said 'main character energy' and then locked me out.", category: .slang),

        // MARK: Hygiene
        PottyLine(text: "Wash your hands like you're a guest star in a soap opera.", category: .hygiene),
        PottyLine(text: "Twenty seconds. That's one chorus of your favorite song.", category: .hygiene),
        PottyLine(text: "If you can't see the soap, it's not a personality test. Ask.", category: .hygiene),
        PottyLine(text: "Paper towel on the door handle: low effort, high status.", category: .hygiene),
        PottyLine(text: "The sink is not a suggestion box.", category: .hygiene),
        PottyLine(text: "Hand sanitizer is the understudy, not the lead.", category: .hygiene),
        PottyLine(text: "Dry your hands before you touch your phone. Your phone has seen things.", category: .hygiene),
        PottyLine(text: "Elbow the door. It's called range.", category: .hygiene),
        PottyLine(text: "If the floor is wet, assume it's a trap.", category: .hygiene),
        PottyLine(text: "Never trust a bathroom that smells like a candle store and nothing else.", category: .hygiene),

        // MARK: Thread starters
        PottyLine(text: "Settle this: is the work bathroom a break, or a destination?", category: .thread),
        PottyLine(text: "What's the most unhinged bathroom sign you've ever read?", category: .thread),
        PottyLine(text: "Be honest: do you sit or hover? (Anonymous. Probably.)", category: .thread),
        PottyLine(text: "Name a place whose bathroom is better than the food.", category: .thread),
        PottyLine(text: "What's your 'I need a bathroom NOW' route in this city?", category: .thread),
        PottyLine(text: "Would you rather: no soap or no paper?", category: .thread),
        PottyLine(text: "Rate the air dryer. Be brutal.", category: .thread),
        PottyLine(text: "What's the best bathroom you've ever used? I'll go first.", category: .thread)
    ]

    static func lines(in category: LineCategory) -> [PottyLine] {
        all.filter { $0.category == category }
    }

    static func random(excluding recent: Set<String> = []) -> PottyLine {
        let pool = all.filter { !recent.contains($0.id) }
        return (pool.isEmpty ? all : pool).randomElement() ?? all[0]
    }

    /// The line shown on the comedy "shuffle" surface.
    static func randomAny() -> PottyLine {
        all.randomElement() ?? all[0]
    }
}
