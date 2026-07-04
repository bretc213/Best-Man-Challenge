//
//  MurderMysteryData.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — all game content (suspects, drops, locations, challenges)
//

import Foundation

enum MurderMysteryData {

    static let finalWeek = 13

    // MARK: - Accusation options

    static let killerOptions = [
        "Charlene Hargrove", "Colt Hargrove", "Earl Dunbar",
        "Tiffany Voss", "Sheriff Buck Tillman", "Dani Reyes"
    ]

    static let weaponOptions = [
        "Rattlesnake Venom", "Branding Iron", "Hunting Rifle",
        "Bolo Tie (Garrote)", "Blunt Force — Oil Pipe", "Poison in Whiskey"
    ]

    static let locationOptions = [
        "The Ranch House", "The Oil Derrick", "The Barn & Stables",
        "The Hunting Cabin", "The Honky-Tonk", "The Underground Bunker"
    ]

    // The true solution — used for scoring in test mode. Never displayed.
    static let solutionKiller = "Charlene Hargrove"
    static let solutionWeapon = "Rattlesnake Venom"
    static let solutionLocation = "The Underground Bunker"

    // MARK: - Point multipliers

    static func multiplier(forWeek week: Int) -> Double {
        switch week {
        case 1...2:   return 5.0
        case 3...4:   return 4.0
        case 5...6:   return 3.0
        case 7...9:   return 2.0
        case 10...12: return 1.0
        case 13:      return 0.5
        default:      return 0.0
        }
    }

    // MARK: - Suspects

    static let suspects: [Suspect] = [
        Suspect(
            id: "charlene",
            name: "Charlene Hargrove",
            role: "Wade's Wife (3rd Marriage) · Age 45",
            bio: "Married Wade five years ago after a whirlwind courtship. Elegant, composed, and tight-lipped about her past. Roy disapproved of her openly — the two had a long-running tension Wade pretended not to notice.",
            details: [
                ("Age", "45"),
                ("Origin", "Claims Dallas — records incomplete before 2009"),
                ("Alibi", "In her room all evening, took a sleeping pill, no witness"),
                ("Known for", "Composure, no fear of animals including snakes"),
                ("With Roy", "Cold — Roy once called her \"not who she says she is\"")
            ],
            colorHex: "#7a3a5a"
        ),
        Suspect(
            id: "colt",
            name: "Colt Hargrove",
            role: "Wade's Son (1st Marriage) · Age 42",
            bio: "Wade's only son. Bitter about the prenup, bitter about Charlene, bitter about most things. Roy knew about serious gambling debts — six figures owed to someone in Houston — and had threatened to tell Wade.",
            details: [
                ("Age", "42"),
                ("Background", "Failed oil venture in Midland, currently broke"),
                ("Alibi", "Claims he was at the honky-tonk until midnight"),
                ("Known for", "Hunting, lying, spending money"),
                ("With Roy", "Feared him — Roy had leverage")
            ],
            colorHex: "#6a3a1a"
        ),
        Suspect(
            id: "earl",
            name: "Earl Dunbar",
            role: "Business Partner · Age 68",
            bio: "Old money, old grudges. Earl and Wade built their fortunes together in the '80s. A 1998 land deal gone sour left bad blood — and Roy had documentation Earl would prefer didn't exist.",
            details: [
                ("Age", "68"),
                ("Background", "Oil and cattle, semi-retired"),
                ("Alibi", "Playing cards with Buck until 10pm"),
                ("Known for", "Finance and pressure"),
                ("With Roy", "Disputed — Roy held a deed with Earl's name in the wrong place")
            ],
            colorHex: "#3a3a5a"
        ),
        Suspect(
            id: "tiffany",
            name: "Tiffany Voss",
            role: "Reality TV Producer · Age 35",
            bio: "Nobody remembers inviting her. She was caught twice near Wade's private office and had hidden cameras running the whole time — but her equipment went missing the morning Roy was found.",
            details: [
                ("Age", "35"),
                ("Background", "LA-based, several cancelled reality shows"),
                ("Alibi", "Reviewing footage in her room, alone"),
                ("Known for", "Being everywhere she shouldn't be"),
                ("With Roy", "Roy caught her in Wade's office — confrontation ensued")
            ],
            colorHex: "#6a2a3a"
        ),
        Suspect(
            id: "buck",
            name: "Sheriff Buck Tillman",
            role: "Local Sheriff · Age 55",
            bio: "The county sheriff — technically. In practice, on Wade's payroll for years. Roy was the one keeping records of those payments. When Wade said he wouldn't call the sheriff, Buck was not surprised.",
            details: [
                ("Age", "55"),
                ("Background", "Fredericksburg born, 22 years as sheriff"),
                ("Alibi", "Cards with Earl then \"patrolling\" — vague"),
                ("Known for", "Making things disappear"),
                ("With Roy", "Despised him — Roy had records of every payment")
            ],
            colorHex: "#4a3a1a"
        ),
        Suspect(
            id: "dani",
            name: "Dani Reyes",
            role: "Charlene's Niece · Age 29",
            bio: "Quiet. Observant. Arrived with Charlene and stays close. Was the last person seen near Roy before he disappeared. Claims they just talked. Her phone told a different story.",
            details: [
                ("Age", "29"),
                ("Background", "San Antonio, grad student — art history"),
                ("Alibi", "Walked Roy toward the barn ~9pm, says he went on alone"),
                ("Known for", "Loyalty to Charlene — little else known"),
                ("With Roy", "Newly acquainted, suspiciously so")
            ],
            colorHex: "#1a4a3a"
        )
    ]

    // MARK: - Drops

    static let drops: [Drop] = [
        Drop(
            id: "w0-major", week: 0, isMidweek: false,
            title: "Case File — Welcome to Hargrove Ranch",
            body: """
            Wade Hargrove's 70th birthday gathering was supposed to be five days of Texas hospitality — good whiskey, live music, and old stories. Twelve guests arrived on a Tuesday. By Thursday morning, Roy Mackay was dead.

            Roy was the foreman. Thirty years on this land. Found at the base of the old oil derrick at 6:12am by one of the ranch hands. The local paper called it an accident. Wade knows better.

            He's not calling the sheriff. He says he has his reasons. He wants to know what happened before he decides what to do about it.

            "Roy knew something about everybody here. That's the problem. Too many people had a reason to keep him quiet." — Wade Hargrove
            """,
            clueNote: nil
        ),
        Drop(
            id: "w1-major", week: 1, isMidweek: false,
            title: "The Discovery",
            body: """
            Roy Mackay's body was found face-down at the base of Oil Derrick #3, roughly 400 yards east of the main house. Time of death: 10pm–1am. A deep laceration to the back of the skull, consistent with a fall — or a blow.

            Witness statements from the night of:
            • Charlene: "I was in bed by nine. I took a sleeping pill. I didn't hear anything."
            • Colt: "I was at Dad's honky-tonk in town until almost midnight. Ask the bartender."
            • Earl: "Playing cards with Buck in the sitting room. We called it around ten."
            • Tiffany: "Reviewing footage in my room. I had headphones in."
            • Sheriff Buck: "Left Earl around ten, drove a loop around the property. Routine."
            • Dani: "I walked with Roy toward the barn around nine. He said he was checking on something. I came back to the house alone."
            """,
            clueNote: "🔑 Ranch House desk combo — first digit is 7"
        ),
        Drop(
            id: "w1-mid", week: 1, isMidweek: true,
            title: "Roy's Bunk",
            body: """
            A photo inventory of Roy's bunk room. Among his effects: a worn Bible, a box of .45 shells, three sets of work gloves, a framed photo of the ranch circa 1997, and a letter — torn in half. Only the top half present.

            The letter begins: "Wade, I've been sitting on this for too long. There's something about Charlene you need to see. The photograph I found in the—"

            The bottom half is missing. Also found: half of a polaroid photograph. Two people, younger, smiling somewhere that isn't Texas. One of them is Roy. The other's face is obscured by a fold.
            """,
            clueNote: nil
        ),
        Drop(
            id: "w2-major", week: 2, isMidweek: false,
            title: "The Medical Report",
            body: """
            Preliminary cause of death: blunt force trauma to the head. The medical examiner's initial finding is consistent with a fall — striking the derrick structure on the way down, then the ground.

            Two anomalies flagged: (1) trace compounds in Roy's bloodstream, not yet identified. (2) A blood spatter pattern inconsistent with a simple fall. The ME has flagged this for further toxicology.

            Wade also received a handwritten note Roy sent three days before the gathering: "I need to talk to you alone. Not during the party. The night before. It's about the ranch. And about her." Wade declined. He wishes he hadn't.
            """,
            clueNote: "🔑 Desk combo — second digit is 4  |  Roy's lockbox — second digit is 8"
        ),
        Drop(
            id: "w2-mid", week: 2, isMidweek: true,
            title: "The Voicemail",
            body: """
            Roy left a voicemail at 9:47pm the night he died. The recipient's number traces to a prepaid phone — no registered owner.

            Transcript: "It's Roy. I know you're not gonna pick up. I'm going to show Wade tomorrow, first thing. He needs to know what she did — what she really did, back before all this. I've got the photograph. I've got the deed paperwork. If something happens to me tonight, you know where I keep things."

            The call lasted 38 seconds.
            """,
            clueNote: "🔑 Desk combo — third digit is 2. Complete combo: 7-4-2"
        ),
        Drop(
            id: "w3-major", week: 3, isMidweek: false,
            title: "Colt's Debts",
            body: """
            Financial records reveal Colt Hargrove owes $340,000 to a lending operation in Houston with organized crime ties. Payments missed for four months.

            More damning: $180,000 of Hargrove Ranch operating funds were transferred to an account in Colt's name over the past two years. Roy discovered this eight months ago during a routine audit. He confronted Colt privately. Colt paid him $15,000 cash to stay quiet. Roy stopped cashing the checks three months ago.
            """,
            clueNote: "🔑 Lockbox — first digit is 3"
        ),
        Drop(
            id: "w3-mid", week: 3, isMidweek: true,
            title: "A Strange Receipt — Fragment 1/5",
            body: """
            Found tucked inside Roy's saddle bag in the barn: a receipt fragment. Partial text visible — a purchase from a sporting goods store in Kerrville, dated six weeks before Roy's death.

            Items partially legible: "...hook, lg." and "...glv leather med."

            The credit card number is cut off. The bottom of the receipt is missing.
            """,
            clueNote: "🔑 Receipt Fragment 1 of 5 recovered"
        ),
        Drop(
            id: "w4-major", week: 4, isMidweek: false,
            title: "Earl's Land Deal",
            body: """
            A 1998 deed surfaces — a parcel on the western edge of Hargrove property, transferred under circumstances Roy documented meticulously. The deed shows Roy Mackay as a witness. Earl Dunbar's signature appears in a place it legally should not.

            If the transfer was fraudulent, Earl's stake in a 2004 mineral rights deal — worth an estimated $2.3 million — becomes legally void. Roy had kept copies. Wade didn't know Roy had them.
            """,
            clueNote: "🔑 Receipt Fragment 2 of 5"
        ),
        Drop(
            id: "w4-mid", week: 4, isMidweek: true,
            title: "Dani's Texts",
            body: """
            Dani gave her phone to Wade voluntarily. A recovered text chain from the night of the murder — sender listed simply as "C":

            C: Is he gone yet
            Dani: yes I got him to the barn path
            C: good keep walking back say you left him at the fork
            Dani: ok. Is everything ok
            C: it will be

            The contact "C" is not further identified in Dani's phone.
            """,
            clueNote: "🔑 Notebook cipher key — Part 1 of 3: ROT-13 (A→N, B→O, C→P…)"
        ),
        Drop(
            id: "w5-major", week: 5, isMidweek: false,
            title: "Charlene's Background",
            body: """
            A background check returns inconsistencies. "Charlene Vail" does not appear in Texas state records before 2009. What does appear: a "Charlotte Vela" from Uvalde, Texas — same approximate age — who worked at the Uvalde Wildlife Rehabilitation Center from 2001–2006.

            Specialty: reptiles. Center intake logs show she handled venomous snakes without protective equipment and was considered expert-level by staff.

            Charlene has not commented. When Wade mentioned the wildlife center in passing, she went very still.
            """,
            clueNote: nil
        ),
        Drop(
            id: "w5-mid", week: 5, isMidweek: true,
            title: "A Guest's Journal",
            body: """
            An anonymous journal left in the main house common room. Handwriting matches one of the guests (unconfirmed). An entry from the night Roy died:

            "Couldn't sleep. 11:12pm — there was a light in the bunker. Not the kind that happens by accident. Someone opened it, went in, and after maybe twenty minutes it went dark again. I didn't tell anyone because I don't know what that means. I'm starting to think I should have."
            """,
            clueNote: "🔑 Notebook cipher key — Part 2 of 3  |  Lockbox — third digit is 1. Full combo: 3-8-1"
        ),
        Drop(
            id: "w6-major", week: 6, isMidweek: false,
            title: "The Photographs",
            body: """
            The photographs from Roy's lockbox. Eight are mundane ranch shots. One is not: Roy and a young woman, standing outside a building marked "Uvalde Wildlife Rehab Center," dated 2004. Roy has his arm around her. She's laughing.

            She looks exactly like Charlene Hargrove.
            """,
            clueNote: "🔑 Receipt Fragment 3 of 5"
        ),
        Drop(
            id: "w6-mid", week: 6, isMidweek: true,
            title: "The Other Half",
            body: """
            The second half of the polaroid photograph from Roy's bunk room has surfaced — found behind a loose board in the barn.

            Reunited with the first half, the full photograph shows: Roy and Charlene. Young. Smiling. A sign in the background reads "Uvalde, TX — Annual Rodeo & Fair, 2003." They knew each other long before she ever met Wade.
            """,
            clueNote: nil
        ),
        Drop(
            id: "w7-major", week: 7, isMidweek: false,
            title: "Buck's Deal",
            body: """
            Evidence of Sheriff Tillman's arrangement with Wade — cash payments over seven years for overlooking certain permits, a land-use dispute, and two incidents involving Colt. Roy was the one keeping the ledger.

            If exposed, Tillman loses his badge, his pension, and faces federal corruption charges. Roy was the only person outside Wade who knew the full scope of it.
            """,
            clueNote: "🔑 Receipt Fragment 4 of 5  |  Bunker bypass — digit 1 is 5"
        ),
        Drop(
            id: "w7-mid", week: 7, isMidweek: true,
            title: "Last Call — A Note from Roy",
            body: """
            Found in Roy's jacket pocket, handwritten on a cocktail napkin:

            "Pete poured me the last one. I told him it was the Last Call I needed. Walked out. She was already gone. I should've known from the whiskey."

            Roy's shorthand for his favorite drink at the bar — the only thing he ever ordered — was simply what he called it. Pete the bartender confirms Roy ordered the same thing every time without fail.
            """,
            clueNote: "🔑 Honky-Tonk back room password hidden in this drop  |  Notebook cipher key — Part 3 of 3 unlocked"
        ),
        Drop(
            id: "w8-major", week: 8, isMidweek: false,
            title: "Tiffany's Secret",
            body: """
            Tiffany had a hidden agenda: she was filming everything on concealed devices. She captured footage from the night Roy died on a motion-sensor camera in the main hall — but the SD card was removed before she could review it.

            Separately: circumstantial evidence continues building against Colt. The timeline of his alibi has another gap. The borrowed money, the leverage Roy had, the temper — it's almost too clean a case.
            """,
            clueNote: "🔑 Receipt Fragment 5 of 5 — all five fragments now available"
        ),
        Drop(
            id: "w8-mid", week: 8, isMidweek: true,
            title: "The Letter — Bottom Half",
            body: """
            The missing bottom half of Roy's letter (from the Ranch House desk) has been recovered. It continues:

            "—safe in the barn. I've also got a voicemail she left me in 2019. She thought I'd deleted it. I didn't. Wade, I'm sorry I waited so long. I should have told you years ago what happened in Uvalde. What she did, and why I let her walk. I was wrong. Don't trust her alone with anyone."
            """,
            clueNote: nil
        ),
        Drop(
            id: "w9-major", week: 9, isMidweek: false,
            title: "The Colt Pivot",
            body: """
            New evidence complicates the case against Colt. Security footage from the honky-tonk confirms Colt's presence until 11:52pm — his alibi for the core window holds.

            A second review of the medical report: trace compounds in Roy's bloodstream are now partially identified — organophosphates consistent with venom protein breakdown. Not consistent with a blow to the head.

            Roy may not have died from the fall at all.
            """,
            clueNote: "🔑 Bunker bypass — digit 2 is 2"
        ),
        Drop(
            id: "w9-mid", week: 9, isMidweek: true,
            title: "Wade's Calendar",
            body: """
            Roy's meeting request, recovered from Wade's private computer (Ranch House Hard challenge):

            Subject: "Re: Charlene / Uvalde"
            Proposed time: the evening before the gathering. Wade declined.

            A note in Wade's handwriting below the entry: "If Roy's right, I don't know what I've done. Or what she's capable of."

            Wade wrote that note before Roy died. He never followed up.
            """,
            clueNote: nil
        ),
        Drop(
            id: "w10-major", week: 10, isMidweek: false,
            title: "The Venom",
            body: """
            Updated toxicology: Roy died of rattlesnake venom administered orally — specifically Crotalus atrox, western diamondback. The head trauma happened postmortem. The fall was staged.

            Estimated time of death: 10:15–11pm. Roy was dead before he reached the derrick. Someone moved the body.

            The bunker light seen at 11:12pm in the guest's journal now carries new weight.
            """,
            clueNote: "🔑 Bunker bypass — digit 3 is 9  |  Cabin safe letter code is RK"
        ),
        Drop(
            id: "w10-mid", week: 10, isMidweek: true,
            title: "The Burner Phone Messages",
            body: """
            Recovered from behind the fireplace in the hunting cabin (Cabin Medium challenge):

            SENT: "It's done."
            RECOVERED DELETED: "Use the cabin tonight. He won't make it to morning."

            Phone purchased at a gas station in Fredericksburg. Security camera image: a woman in a wide-brimmed hat. Hair color matches Charlene Hargrove. Timestamp: six days before Roy's death.
            """,
            clueNote: nil
        ),
        Drop(
            id: "w11-major", week: 11, isMidweek: false,
            title: "The Bunker",
            body: """
            Wade confirms the underground bunker exists. He built it in 2009. Access code known only to him — he thought.

            The bunker has five rooms. One is behind a secondary keypad: a private study Wade used for sensitive documents. Nobody else was supposed to know it existed.

            Somebody did.
            """,
            clueNote: "🔑 Bunker bypass — digit 4 is 3. Full bypass: 5-2-9-3"
        ),
        Drop(
            id: "w11-mid", week: 11, isMidweek: true,
            title: "The Flight",
            body: """
            Recovered from the hunting cabin wall safe (Cabin Hard challenge): a travel itinerary.

            Name: Charlene Hargrove | Route: Austin–Bergstrom → Mexico City Benito Juárez | Type: One way | Departure: 6:40am, the morning after Roy died.

            She cancelled the booking at 8:17am — seventeen minutes after Wade locked down the ranch and announced Roy's death to the gathered guests.
            """,
            clueNote: nil
        ),
        Drop(
            id: "w12-major", week: 12, isMidweek: false,
            title: "Everything Connects",
            body: """
            Wade has assembled his full private investigation. Charlene Vela and Roy Mackay grew up in the same county. She worked at the wildlife center and learned to handle venomous snakes. Roy had evidence from 2006 and let her walk. She disappeared, then resurfaced as "Charlene Vail" in Wade's orbit — and she specifically sought Roy out.

            She knew he had the photograph, the voicemail, the paperwork. She used Dani to lead Roy to the bunker. She brought whiskey. She knew exactly what she was doing. When Roy finally decided to tell Wade, she acted. The bunker. The venom. The staged scene at the derrick. The flight she almost took.
            """,
            clueNote: "🔑 Final decrypt key — Part 3: BUNKER (complete password now available)"
        ),
        Drop(
            id: "w12-mid", week: 12, isMidweek: true,
            title: "The Last Piece",
            body: """
            The hidden camera in the bunker study — installed by Wade in 2009 and forgotten — was still recording.

            The footage is encrypted but recoverable. Players who complete the Bunker Hard challenge see the full recording.

            Wade says he already knows what's on it. He just needed the investigation to confirm it before he decides what comes next.
            """,
            clueNote: nil
        )
    ]

    // MARK: - Locations & Challenges

    static let locations: [InvestigationLocation] = [
        InvestigationLocation(
            id: "ranch-house",
            name: "The Ranch House",
            description: "The main residence. Wade's private study, guest bedrooms, a formal dining hall. Everyone passed through here.",
            unlocksWeek: 1,
            challenges: [
                Challenge(
                    id: "rh-easy",
                    name: "The Guest Registry",
                    difficulty: .easy, points: 50,
                    description: "Match each guest's signature in the registry to their stated alibi timeline. One guest signed back in at a time that contradicts their story — nearly two hours after they claimed to be in their room. Who?",
                    type: .multipleChoice(["Charlene Hargrove", "Colt Hargrove", "Earl Dunbar", "Tiffany Voss", "Sheriff Buck Tillman", "Dani Reyes"]),
                    answerKey: "Tiffany Voss",
                    rewardText: "The registry shows Tiffany signed back in at 11:48pm — nearly two hours after she claims she was reviewing footage in her room. Her alibi has a two-hour hole."
                ),
                Challenge(
                    id: "rh-desk",
                    name: "Wade's Desk Drawer",
                    difficulty: .medium, points: 150,
                    description: "A 3-digit combination lock on Wade's private desk drawer. The combination was split across three early drops — one digit per drop.",
                    type: .textInput(placeholder: "000", hint: "Digit 1 → Week 1 major drop. Digit 2 → Week 2 major drop. Digit 3 → Week 2 mid-week drop."),
                    answerKey: "742",
                    rewardText: "Inside: the bottom half of Roy's torn letter. It continues: \"—safe in the barn. I've also got the voicemail she left me in 2019. She thought I'd deleted it. I didn't. Wade, I'm sorry I waited so long. Don't trust her alone with anyone.\""
                ),
                Challenge(
                    id: "rh-pc",
                    name: "Wade's Private Computer",
                    difficulty: .hard, points: 300,
                    description: "Password required. Built from a year and a name. The year comes from Earl's Land Deal drop. The name comes from the registry easy challenge. All caps, no spaces.",
                    type: .textInput(placeholder: "YEARNAME", hint: "Year = the year of the fraudulent land deed (Week 4 major drop). Name = the suspect whose alibi broke (registry easy challenge). Combine: YEAR+NAME, all caps, no spaces."),
                    answerKey: "COLT1998",
                    rewardText: "Wade's private calendar: a meeting request from Roy, two days before the murder — Subject: \"Re: Charlene / Uvalde.\" Wade declined it. Below it, in Wade's handwriting: \"If Roy's right, I don't know what I've done.\""
                )
            ]
        ),
        InvestigationLocation(
            id: "oil-derrick",
            name: "The Oil Derrick",
            description: "Where Roy's body was found. Derrick #3, east of the main house. Last operational in 2011. The official crime scene.",
            unlocksWeek: 1,
            challenges: [
                Challenge(
                    id: "derrick-easy",
                    name: "Scratched Message",
                    difficulty: .easy, points: 50,
                    description: "Numbers and letters are scratched into the base of the derrick — Roy's handwriting. Beneath a partial word, he scratched two smaller words. What did Roy scratch?",
                    type: .multipleChoice(["NOT HERE", "HELP ME", "SHE DID IT", "BODY MOVED", "FIND CHARLENE"]),
                    answerKey: "NOT HERE",
                    rewardText: "\"NOT HERE.\" Roy scratched this himself — he knew he was in danger and left a message. The body was moved to the derrick. Whatever happened to Roy happened somewhere else entirely."
                ),
                Challenge(
                    id: "derrick-medium",
                    name: "The Hidden Compartment",
                    difficulty: .medium, points: 150,
                    description: "Roy hid something in the old derrick equipment casing. The key word to access it: what was Roy being led toward the night he died? One word, from Dani's text chain.",
                    type: .textInput(placeholder: "ONE WORD", hint: "In Dani's text thread (Week 4 mid-week), what location did she guide Roy toward? That word — all caps — unlocks the compartment."),
                    answerKey: "BARN",
                    rewardText: "A sealed vial inside a wrapped cloth. Dark amber residue. Later analysis confirms: extracted Crotalus atrox venom — western diamondback rattlesnake. Enough to kill a man if introduced orally — in, say, a glass of whiskey."
                ),
                Challenge(
                    id: "derrick-hard",
                    name: "The Blood Pattern",
                    difficulty: .hard, points: 300,
                    description: "A forensic specialist has analyzed the blood evidence. Based on all evidence gathered — the medical report anomalies, the body position, the \"NOT HERE\" message — what is the correct conclusion?",
                    type: .multipleChoice(["Roy was killed here and fell", "The scene was staged — Roy died elsewhere", "Roy was injured elsewhere and crawled here", "Two people fought here and Roy lost", "Roy fell from the top of the derrick"]),
                    answerKey: "The scene was staged — Roy died elsewhere",
                    rewardText: "Confirmed: the blood pattern, venom in the toxicology, and Roy's own message establish that the derrick is a staged scene. Roy Mackay was already dead when he arrived here. Someone moved a body in the dark."
                )
            ]
        ),
        InvestigationLocation(
            id: "barn",
            name: "The Barn & Stables",
            description: "Roy's domain. His locker, his workspace, his coded notebook. The last place Dani admits leading him before he \"went on alone.\"",
            unlocksWeek: 3,
            challenges: [
                Challenge(
                    id: "barn-easy",
                    name: "Roy's Locker",
                    difficulty: .easy, points: 50,
                    description: "Roy's personal locker is open. His inventory: work boots (size 11), a spare jacket, a pocket knife with his initials, a horse feed receipt, and one item that clearly doesn't belong to Roy. Based on the suspect profiles, who does this item belong to?",
                    type: .multipleChoice(["Charlene Hargrove", "Colt Hargrove", "Earl Dunbar", "Tiffany Voss", "Sheriff Buck Tillman", "Dani Reyes"]),
                    answerKey: "Charlene Hargrove",
                    rewardText: "A silk scarf, monogrammed C.V. — Charlene Vail, her maiden name. Why did Charlene Hargrove's scarf end up in Roy's personal locker?"
                ),
                Challenge(
                    id: "barn-box",
                    name: "Roy's Lockbox",
                    difficulty: .medium, points: 150,
                    description: "A fireproof lockbox under Roy's workbench. Three-digit combination released across three separate drops.",
                    type: .textInput(placeholder: "000", hint: "Digit 1 → Week 3 major drop. Digit 2 → Week 2 major drop. Digit 3 → Week 5 mid-week drop."),
                    answerKey: "381",
                    rewardText: "Inside: eight mundane ranch photos — and one that isn't. Roy and a young woman outside \"Uvalde Wildlife Rehab Center,\" dated 2004. Roy has his arm around her. She's laughing. She looks exactly like Charlene Hargrove."
                ),
                Challenge(
                    id: "barn-notebook",
                    name: "Roy's Coded Notebook",
                    difficulty: .hard, points: 300,
                    description: "Roy kept a notebook in ROT-13 substitution cipher. Using the full cipher key (released across Weeks 4, 5, and 7 mid-week drops), decode his final entry. What substance does his last line name?",
                    type: .textInput(placeholder: "ONE WORD", hint: "Full cipher: ROT-13 (A→N, N→A). Apply it to: JUV FXRL. What one word does that decode to?"),
                    answerKey: "WHISKEY",
                    rewardText: "Roy's final entry decoded: \"She came to the cabin. Brought the good whiskey. Said she wanted to talk. I should have known. The whiskey tasted wrong. I left fast. If you're reading this—\" It ends there. He didn't finish."
                )
            ]
        ),
        InvestigationLocation(
            id: "cabin",
            name: "The Hunting Cabin",
            description: "Two miles from the main house. Listed as unoccupied during the gathering. It was not.",
            unlocksWeek: 5,
            challenges: [
                Challenge(
                    id: "cabin-easy",
                    name: "Signs of Life",
                    difficulty: .easy, points: 50,
                    description: "The cabin shows clear signs of recent occupation. Among the evidence, one item directly ties a specific suspect to the cabin. What was it?",
                    type: .multipleChoice(["A men's razor (Colt's brand)", "A lipstick-marked glass (Charlene's shade)", "A camera SD card (Tiffany's model)", "A sheriff badge pin", "A grad school textbook (Dani's university)"]),
                    answerKey: "A camera SD card (Tiffany's model)",
                    rewardText: "A 64GB SD card matching Tiffany Voss's exact camera model — the equipment that went \"missing\" the morning Roy was found. Either Tiffany was at the cabin, or someone removed the card and stored it here."
                ),
                Challenge(
                    id: "cabin-map",
                    name: "The Hidden Compartment",
                    difficulty: .medium, points: 150,
                    description: "Two halves of a map were released in Weeks 5 and 6 drops. Combined, they show a hidden compartment location inside the cabin. Which room does the map point to?",
                    type: .multipleChoice(["Under the floorboards", "Behind the fireplace", "Inside the kitchen wall", "Below the porch steps", "In the loft above the bed"]),
                    answerKey: "Behind the fireplace",
                    rewardText: "Behind a loose hearthstone: a burner phone. One sent message: \"It's done.\" One recoverable deleted message: \"Use the cabin tonight. He won't make it to morning.\" Purchased in Fredericksburg six days before Roy's death."
                ),
                Challenge(
                    id: "cabin-safe",
                    name: "The Wall Safe",
                    difficulty: .hard, points: 300,
                    description: "A small safe requires the Ranch House desk combo (3 digits) plus a 2-letter code from the Week 10 major drop. Enter all 5 characters together, no spaces.",
                    type: .textInput(placeholder: "000XX", hint: "First 3 chars = Ranch House desk answer. Last 2 chars = the letter code from Week 10 major drop. Enter as one string, e.g. 000RK"),
                    answerKey: "742RK",
                    rewardText: "A travel itinerary. Name: Charlene Hargrove. Austin–Bergstrom to Mexico City. One way. Departure: 6:40am the morning after Roy died. She cancelled at 8:17am — seventeen minutes after Wade locked down the ranch."
                )
            ]
        ),
        InvestigationLocation(
            id: "honky-tonk",
            name: "The Honky-Tonk",
            description: "Wade built it himself on the edge of Fredericksburg. Roy was here two nights before he died. So was someone else.",
            unlocksWeek: 7,
            challenges: [
                Challenge(
                    id: "htk-bartender",
                    name: "Talk to Pete",
                    difficulty: .easy, points: 50,
                    description: "Pete Garza worked the bar the night Roy came in two days before his death. To get Pete to open up, you have to ask the right question. Which question gets the most useful answer?",
                    type: .multipleChoice(["Did Roy seem scared?", "Who did Roy talk to that night?", "Did Roy leave with anyone?", "What did Roy order?", "Did anyone follow Roy out?"]),
                    answerKey: "Who did Roy talk to that night?",
                    rewardText: "Pete: \"Roy talked to one person the whole night. Sat in the back booth almost an hour. A woman. Blonde. Pretty. Not from around here. She left before he did. He looked shook up after.\" The description matches Charlene Hargrove."
                ),
                Challenge(
                    id: "htk-password",
                    name: "The Back Room",
                    difficulty: .medium, points: 150,
                    description: "Wade had a private back room for business meetings. Password protected. The password is hidden in the Week 7 mid-week drop — Roy's handwritten note. What was the last drink Roy ever ordered at the bar?",
                    type: .textInput(placeholder: "PASSWORD", hint: "Week 7 mid-week: Roy refers to his last drink by name. He ordered the same thing every time. Pete confirms it. One word, all caps, no spaces."),
                    answerKey: "LASTCALL",
                    rewardText: "Bar security footage description: 9:14pm, two nights before the murder. Roy enters. 9:22pm: a woman in a wide-brimmed hat enters, sits across from Roy. 10:31pm: she leaves. 10:47pm: Roy leaves alone, visibly unsteady. Hat style matches Charlene's."
                ),
                Challenge(
                    id: "htk-receipt",
                    name: "The Complete Receipt",
                    difficulty: .hard, points: 300,
                    description: "Five fragments of a single receipt scattered across the investigation (Weeks 3, 4, 6, 7, 8). Assembled, they reveal who purchased snake handling equipment six weeks before Roy's death.",
                    type: .multipleChoice(["Sheriff Buck Tillman", "Colt Hargrove", "Charlene Hargrove", "Earl Dunbar", "Tiffany Voss"]),
                    answerKey: "Charlene Hargrove",
                    rewardText: "Complete receipt: Kerrville Outdoors & Feed. Snake hook (lg) — $44.99. Leather handling gloves (med) — $28.00. Visa ending 8814 — registered to Charlotte Vela. Charlene Hargrove's name before she changed it."
                )
            ]
        ),
        InvestigationLocation(
            id: "bunker",
            name: "The Underground Bunker",
            description: "Wade built it in 2009 and forgot about it. Somebody else didn't forget.",
            unlocksWeek: 11,
            challenges: [
                Challenge(
                    id: "bunker-easy",
                    name: "Navigate the Bunker",
                    difficulty: .easy, points: 50,
                    description: "Using the partial map from the Week 11 major drop, identify the locked room behind the secondary keypad. What is this room labeled?",
                    type: .multipleChoice(["Storage B", "Generator Room", "The Study", "Cold Room", "Primary Shelter"]),
                    answerKey: "The Study",
                    rewardText: "The Study — Wade's private secondary office. A room he told no one about. Not his lawyers. Not his son. Not his wife."
                ),
                Challenge(
                    id: "bunker-bypass",
                    name: "Biometric Override",
                    difficulty: .medium, points: 150,
                    description: "The secondary keypad has a 4-digit emergency bypass. One digit released per drop across Weeks 7, 9, 11, and 11 mid-week.",
                    type: .textInput(placeholder: "0000", hint: "Week 7 major = 5 · Week 9 major = 2 · Week 11 major = 9 · Week 11 mid-week = 3. Enter in order."),
                    answerKey: "5293",
                    rewardText: "The Study: a broken whiskey glass on the floor — Roy's brand. Dark staining on the concrete. A single rattlesnake scale near the drain. This is where Roy Mackay actually died. Not the derrick."
                ),
                Challenge(
                    id: "bunker-decrypt",
                    name: "The Final Recording",
                    difficulty: .hard, points: 300,
                    description: "A hidden camera recorded everything. The footage is encrypted. Password = barn notebook answer (one word) + current year (4 digits) + BUNKER. All caps, no spaces.",
                    type: .textInput(placeholder: "FULLPASSWORD", hint: "[Barn Hard answer] + [2026] + BUNKER. All caps, no spaces. Example structure: WORD2026BUNKER"),
                    answerKey: "WHISKEY2026BUNKER",
                    rewardText: "The recording shows everything. Charlene entering with Roy. She's calm; he's agitated. He shows her the photograph. She takes it. She hands him a glass of whiskey. He drinks. Within twelve minutes he can't stand. She watches. When it's over, she makes two phone calls and leaves. The camera records forty-seven more minutes of silence."
                )
            ]
        )
    ]

    // MARK: - Lookups

    static func drops(throughWeek week: Int) -> [Drop] {
        drops.filter { $0.week <= week }
    }

    static func openLocations(week: Int) -> [InvestigationLocation] {
        locations.filter { $0.unlocksWeek <= week }
    }
}
