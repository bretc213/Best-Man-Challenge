import Foundation

enum ImageQuizGrader {

    static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isCorrect(
        userAnswer rawUserAnswer: String,
        for question: WeeklyImageQuizQuestion
    ) -> Bool {
        let userAnswer = normalize(rawUserAnswer)
        guard !userAnswer.isEmpty else { return false }

        var accepted: [String] = []
        if let answer = question.answer { accepted.append(answer) }
        accepted.append(contentsOf: question.acceptable_answers ?? [])

        let normalizedAccepted = accepted.map(normalize)

        if normalizedAccepted.contains(userAnswer) {
            return true
        }

        let allowFuzzy = question.allow_fuzzy_match ?? false
        let maxDistance = question.fuzzy_distance ?? 0
        guard allowFuzzy else { return false }

        for candidate in normalizedAccepted {
            if levenshteinDistance(userAnswer, candidate) <= maxDistance {
                return true
            }
        }

        return false
    }

    static func score(
        answersByQuestionId: [String: String],
        questions: [WeeklyImageQuizQuestion],
        pointsPerCorrect: Int
    ) -> (score: Int, breakdown: [String: Bool]) {
        var correctCount = 0
        var breakdown: [String: Bool] = [:]

        for question in questions {
            let userAnswer = answersByQuestionId[question.id] ?? ""
            let correct = isCorrect(userAnswer: userAnswer, for: question)
            breakdown[question.id] = correct
            if correct { correctCount += 1 }
        }

        return (correctCount * pointsPerCorrect, breakdown)
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var dist = Array(
            repeating: Array(repeating: 0, count: b.count + 1),
            count: a.count + 1
        )

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                dist[i][j] = min(
                    dist[i - 1][j] + 1,
                    dist[i][j - 1] + 1,
                    dist[i - 1][j - 1] + cost
                )
            }
        }

        return dist[a.count][b.count]
    }
}
