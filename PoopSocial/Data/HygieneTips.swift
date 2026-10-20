import Foundation
import SwiftUI

// MARK: - Hygiene tips
//
// Real, source-aligned hygiene guidance (CDC-style handwashing and restroom
// etiquette) wrapped in the app's tone. Fun to read, actually useful.

struct HygieneTip: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let icon: String
    let steps: [String]
    let funFact: String
    let xp: Int
}

enum HygieneTips {

    static let all: [HygieneTip] = [
        HygieneTip(
            id: "twenty-seconds",
            title: "The 20-Second Rule",
            blurb: "Soap plus friction plus time is the whole trick. Most people quit at six seconds.",
            icon: "timer",
            steps: [
                "Wet your hands properly — not a polite sprinkle.",
                "Soap up: palms, backs, between fingers, thumbs, nails.",
                "Scrub for about 20 seconds. One chorus of a song.",
                "Rinse, then dry completely. Wet hands spread more than dry ones."
            ],
            funFact: "Hitting 20 seconds is roughly the length of singing 'happy birthday' twice — but slower, and with feeling.",
            xp: 20
        ),
        HygieneTip(
            id: "paper-towel-door",
            title: "The Door Handle Move",
            blurb: "You washed. Don't undo it on the way out.",
            icon: "hand.raised.fill",
            steps: [
                "Grab a paper towel before you touch the handle.",
                "If there's no towel, use your elbow or sleeve.",
                "Never re-touch the sink after drying.",
                "Toss the towel on the way out — not on the floor."
            ],
            funFact: "The exit handle is the most-touched surface in a restroom. It's also the most ignored.",
            xp: 15
        ),
        HygieneTip(
            id: "phone-hygiene",
            title: "Your Phone Is Filthy",
            blurb: "It goes everywhere with you. Including places it shouldn't.",
            icon: "iphone",
            steps: [
                "Don't scroll mid-restroom. Just don't.",
                "Wipe your phone with a screen-safe wipe weekly.",
                "Wash hands before you pick it back up.",
                "Keep it out of the splash zone. You know the one."
            ],
            funFact: "A phone screen can carry more bacteria than a toilet seat — mostly because nobody wipes it.",
            xp: 15
        ),
        HygieneTip(
            id: "hover-hazard",
            title: "The Hover Myth",
            blurb: "Hovering doesn't protect you. It just decorates the seat for the next person.",
            icon: "figure.stand",
            steps: [
                "Use a seat cover or wipe the seat.",
                "Sit. Your thighs are built for this.",
                "Flush with the lid down when there is one.",
                "Wash hands after, every single time."
            ],
            funFact: "Hovering raises splash risk and leaves residue. Sitting on a clean seat is the lower-risk move.",
            xp: 25
        ),
        HygieneTip(
            id: "flush-lid",
            title: "Lid Down, Then Flush",
            blurb: "The flush is an aerosol event. Give it a lid.",
            icon: "arrow.down.circle.fill",
            steps: [
                "Lower the lid before flushing.",
                "If there's no lid, step back and let it settle.",
                "Don't leave anything on top of the tank.",
                "Wash hands even if you only touched the handle."
            ],
            funFact: "Flushing sends a fine spray upward. The lid is the difference between 'contained' and 'ambient'.",
            xp: 20
        ),
        HygieneTip(
            id: "dry-hands",
            title: "Actually Dry Them",
            blurb: "Damp hands pick up more than dry ones. The dryer isn't a formality.",
            icon: "wind",
            steps: [
                "Shake off excess water first.",
                "Use the dryer until fully dry, not until bored.",
                "Paper towel is faster and often more hygienic.",
                "Don't wipe your hands on your clothes. That's a transfer, not a drying."
            ],
            funFact: "Proper drying physically removes remaining microbes. Skipping it undoes a good wash.",
            xp: 10
        ),
        HygieneTip(
            id: "public-seat",
            title: "Public Seat, Calm Mind",
            blurb: "Skin is a great barrier. Panic is optional.",
            icon: "shield.fill",
            steps: [
                "Check for cleanliness before you commit.",
                "Use a cover or a wipe if available.",
                "Avoid touching your face.",
                "Clean your hands before eating or drinking."
            ],
            funFact: "Intact skin is an excellent barrier. The real risk is hand-to-mouth, not the seat itself.",
            xp: 15
        ),
        HygieneTip(
            id: "no-soap",
            title: "No Soap? Improvise",
            blurb: "The plan B kit that lives in your bag.",
            icon: "bag.fill",
            steps: [
                "Carry a small hand sanitizer (at least 60% alcohol).",
                "Use it as a bridge, not a replacement for washing.",
                "Wash properly at the next sink you find.",
                "Wet wipes help with mess, not with germs."
            ],
            funFact: "Sanitizer works best on hands that aren't visibly dirty. If they are, soap and water wins.",
            xp: 20
        ),
        HygieneTip(
            id: "travel-kit",
            title: "Build a Pocket Kit",
            blurb: "Tiny bag, huge peace of mind.",
            icon: "shippingbox.fill",
            steps: [
                "Hand sanitizer, a folded tissue pack, a couple of wipes.",
                "A small sealable bag for the used ones.",
                "A spare mask if you're sensitive to smells.",
                "Restock it once a week. Future you says thanks."
            ],
            funFact: "People who carry a kit stop improvising with paper towels and hope. Hope is not a hygiene plan.",
            xp: 25
        ),
        HygieneTip(
            id: "smell-signal",
            title: "Read the Room",
            blurb: "Your nose is a legitimate review tool.",
            icon: "aqi.medium",
            steps: [
                "Sharp chemical smell often means someone cleaned recently — good sign.",
                "Damp, musty smell means ventilation is losing.",
                "If it's overwhelming, choose another stall or another venue.",
                "Leave a review so the next person knows."
            ],
            funFact: "Ventilation matters as much as cleaning. A spotless room with no airflow still feels wrong.",
            xp: 10
        ),
        HygieneTip(
            id: "leave-it-better",
            title: "Leave It Better",
            blurb: "The golden rule, but with a mop.",
            icon: "sparkles",
            steps: [
                "Wipe the seat if you made a mess — supplies permitting.",
                "Flush fully. A second flush is cheaper than a reputation.",
                "Put paper in the bin where bins exist.",
                "Report broken locks, soap or paper. Someone will fix it."
            ],
            funFact: "Reporting a broken soap dispenser is one of the highest-leverage things you can do in a public bathroom.",
            xp: 30
        ),
        HygieneTip(
            id: "gut-check",
            title: "Body Signals 101",
            blurb: "Funny app, real talk: your gut is data.",
            icon: "heart.fill",
            steps: [
                "Persistent changes in frequency or urgency are worth a doctor visit.",
                "Hydration and fibre do more than any supplement ad.",
                "Blood, black stools or severe pain = get medical advice, not a meme.",
                "This app is fun. It is not a diagnosis."
            ],
            funFact: "Digestive patterns vary wildly between healthy people. 'Normal' is a range, not a single number.",
            xp: 30
        )
    ]

    static func tip(id: String) -> HygieneTip? {
        all.first { $0.id == id }
    }

    /// Deterministic tip-of-the-day so it's stable across launches.
    static func tipOfTheDay(for date: Date = .now) -> HygieneTip {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }

    static let totalXP = all.reduce(0) { $0 + $1.xp }
}
