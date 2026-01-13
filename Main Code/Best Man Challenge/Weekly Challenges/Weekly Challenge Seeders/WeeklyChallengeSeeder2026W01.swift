// this doesn't run, task to run this seeder is commented out

import FirebaseFirestore

enum WeeklyChallengeSeeder2026W01 {

    static func seedQuiz() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w01")

        // Helper to build a question with shuffled options while keeping correct_index accurate
        func makeQuestion(id: String, prompt: String, correct: String, wrong: [String]) -> [String: Any] {
            var options = wrong + [correct]
            options.shuffle()
            let correctIndex = options.firstIndex(of: correct) ?? 0

            return [
                "id": id,
                "prompt": prompt,
                "options": options,
                "correct_index": correctIndex
            ]
        }

        let questions: [[String: Any]] = [
            makeQuestion(
                id: "q1",
                prompt: "What elementary school did Bret go to first?",
                correct: "Valencia",
                wrong: ["Cypress", "Ben Lomand", "Badillo"]
            ),
            makeQuestion(
                id: "q2",
                prompt: "What was Bret's first dog's name?",
                correct: "Destiny",
                wrong: ["Bambi", "Wentz", "Eleven"]
            ),
            makeQuestion(
                id: "q3",
                prompt: "What grade was Bret's first kiss?",
                correct: "7th",
                wrong: ["5th", "6th", "8th"]
            ),
            makeQuestion(
                id: "q4",
                prompt: "What was Bret's first job?",
                correct: "Big League Dreams",
                wrong: ["Crust and Crumble", "In n Out", "CSUF DOps"]
            ),
            makeQuestion(
                id: "q5",
                prompt: "Who was Bret's first favorite Yankee?",
                correct: "Alex Rodriguez",
                wrong: ["Derek Jeter", "Hideki Matsui", "Aaron Judge"]
            ),
            makeQuestion(
                id: "q6",
                prompt: "Who is Bret's favorite basketball player of all time?",
                correct: "Kobe Bryant",
                wrong: ["Lebron James", "Kevin Durant", "Steve Nash"]
            ),
            makeQuestion(
                id: "q7",
                prompt: "Who is Bret's favorite quarterback of all time?",
                correct: "Drew Brees",
                wrong: ["Tom Brady", "Tyler Shough", "Johnny Manziel"]
            ),
            makeQuestion(
                id: "q8",
                prompt: "What is Bret's favorite movie out of the following?",
                correct: "The Best of Me",
                wrong: ["Notebook", "Walk to Remember", "The Last Song"]
            ),
            makeQuestion(
                id: "q9",
                prompt: "What is Bret's favorite movie series?",
                correct: "Harry Potter",
                wrong: ["Star Wars", "Lord of the Rings", "Indiana Jones"]
            ),
            makeQuestion(
                id: "q10",
                prompt: "What was the most touchdown passes Bret has thrown in a single game?",
                correct: "6",
                wrong: ["4", "5", "7"]
            )
        ]

        // ✅ REQUIRED BY YOUR LOADER:
        // week(Int), title(String), description(String), type(String),
        // startDate(Timestamp), endDate(Timestamp)

        // Pick whatever dates you want for Week 1.
        // These are local midnight-ish in PST; adjust if you want.
        let start = Timestamp(date: Date(timeIntervalSince1970: 1735718400)) // 2025-01-01 00:00:00 UTC (example)
        let end   = Timestamp(date: Date(timeIntervalSince1970: 1736323200)) // +7 days (example)

        let data: [String: Any] = [
            // Required fields (exact keys your code expects)
            "week": 1,
            "title": "Week 1: Bret Quiz",
            "description": "10-question multiple choice quiz about Bret. 1 point per correct answer.",
            "type": "quiz",
            "startDate": start,
            "endDate": end,

            // Active flag (keep if your code uses it; doesn’t hurt)
            "is_active": true,

            // Quiz payload
            "quiz": [
                "points_per_correct": 1,
                "questions": questions
            ],

            // Metadata (optional)
            "updated_at": FieldValue.serverTimestamp()
        ]

        // 🔥 Overwrite the entire doc (removes sudoku/cipher fields automatically)
        try await ref.setData(data, merge: false)
        print("✅ Seeded weekly_challenges/2026_w01 as quiz with required fields (overwritten).")
    }
}

