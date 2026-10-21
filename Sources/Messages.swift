import Foundation

/// What she says: a title, plus a smaller line that reminds you to click her.
typealias Line = (title: String, subtitle: String)

enum Messages {
    static let general: [Line] = [
        ("aar. Hydrate. I won't ask twice 💅", "I will, actually. Every 30 minutes."),
        ("Your water bottle filed a missing report 🚨", "Go find it. Click me after."),
        ("Oh, you're busy? Cute. Drink water 💁‍♀️", "Click me when you're done being dramatic"),
        ("I didn't climb up here for nothing 😾", "Sip, then click. That's the deal."),
        ("Dehydrated and thriving? Pick one 💅", "Hint: hydrated. Click me after."),
        ("Even cacti drink more than you 🌵", "Embarrassing. Sip and click."),
        ("aar, your skin called. It's parched 🧴", "Water first, then click me"),
        ("Not to be dramatic, but you're a raisin 🍇", "Fix it, then click me"),
        ("I see you ignoring that glass 👁️", "I see everything. Drink. Click."),
        ("Main character energy needs water ✨", "Sip, then click me"),
        ("This meeting could've been a sip 💧", "Click me once you've hydrated"),
        ("Hydration is hot. Be hot, aar 🔥", "Sip, then click me"),
        ("I'm a cat. I hate water. And yet 🙄", "Do it for me. Click after."),
        ("Water is free, aar. My patience isn't 💸", "Sip and click"),
        ("Ignoring me won't make me leave 😼", "Only a sip and a click will"),
        ("Your brain is 75% water. Respect it 🧠", "Sip, then click"),
        ("Me? Clingy? Drink your water 🐈‍⬛", "Click me when you're done"),
        ("Bestie, your glass is giving empty 🥛", "Refill, sip, click"),
        ("I'm not mad. Just disappointed 😔", "Drink some water, then click me"),
        ("Chop chop, aar. I have naps to take 😴", "Sip, click, and I'm gone"),
        ("Water now, excuses never 💅", "Click me once you've had a sip"),
        ("You're glaring at that screen again 💻", "Blink. Sip. Click me."),
        ("Drink, or I knock things off your desk 🫳", "Click me after you sip"),
        ("Coffee doesn't count, aar. Nice try ☕", "Real water. Then click."),
        ("Don't make me use my disappointed eyes 👀", "Oh wait, these are them. Sip."),
        ("Sip happens. Make it happen, aar 💧", "Then click me, obviously"),
        ("You call that hydrated? Adorable 🙃", "Go again. Click me after."),
        ("I'll wait. I'm very good at staring 😐", "Sip, then click me"),
    ]

    /// Extra lines for the lunch rush.
    static let noon: [Line] = [
        ("Lunch o'clock, aar. Water first 🍱", "Then food. Then click me."),
        ("Midday check: raisin status? 🍇", "Sip, then click me"),
        ("Half the day gone and still thirsty? 🙄", "Fix that, then click"),
        ("Lunch without water is a sad lunch 🥪", "Sip, then click me"),
    ]

    /// Extra lines for the afternoon slump.
    static let afternoon: [Line] = [
        ("4pm slump? That's thirst, darling 🥀", "Sip, then click me"),
        ("It's 4-ish. You're crashing. I know 😼", "Water. Then click."),
        ("Afternoon aar is a dried leaf 🍂", "Rehydrate, then click me"),
        ("Skip the snack. Grab the water 💧", "Then click me, obviously"),
        ("Home stretch. Don't run on empty 🏁", "Sip and click"),
    ]

    /// Lines are dealt from a shuffled deck so you don't see repeats until she's
    /// run through all of them.
    private static var deck: [Line] = []

    static func next(at date: Date = Date()) -> Line {
        let rush: [Line] = switch Schedule.rush(at: date) {
        case .noon: noon
        case .afternoon: afternoon
        case nil: []
        }
        if !rush.isEmpty, Bool.random() { return rush.randomElement()! }
        if deck.isEmpty { deck = general.shuffled() }
        return deck.removeLast()
    }
}

/// When she shows up: every 30 minutes, and more often (at random) around noon and 4pm.
enum Schedule {
    enum Rush { case noon, afternoon }

    static let normalGap: TimeInterval = 30 * 60
    /// During a rush she can pop up any time 10–20 minutes after you last dismissed her.
    static let rushGap: ClosedRange<TimeInterval> = (10 * 60)...(20 * 60)

    /// 11:30–1:00 and 3:30–5:00.
    static func rush(at date: Date) -> Rush? {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        switch minutes {
        case (11 * 60 + 30)..<(13 * 60): return .noon
        case (15 * 60 + 30)..<(17 * 60): return .afternoon
        default: return nil
        }
    }
}
