//
//  TimedQuizWrapperView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/19/26.
//


import SwiftUI

struct TimedQuizWrapperView: View {
    let durationSeconds: Int = 300 // 5 minutes

    @State private var remainingSeconds: Int = 300
    @State private var timerIsRunning = false
    @State private var didExpire = false

    // Your existing quiz state:
    @State private var selectedAnswers: [Int?] = Array(repeating: nil, count: 10)

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {

            // Timer header
            HStack {
                Text("⏱ \(formatTime(remainingSeconds))")
                    .font(.headline)
                Spacer()
                if didExpire {
                    Text("Time’s up")
                        .font(.headline)
                }
            }
            .padding(.horizontal)

            // Your quiz UI goes here
            QuizContentView(
                selectedAnswers: $selectedAnswers,
                isLocked: didExpire
            )

            Button {
                submit()
            } label: {
                Text(didExpire ? "Submitted" : "Submit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(didExpire) // if you auto-submit on expire
            .padding(.horizontal)
        }
        .onAppear {
            remainingSeconds = durationSeconds
            timerIsRunning = true
        }
        .onReceive(timer) { _ in
            guard timerIsRunning, !didExpire else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                didExpire = true
                timerIsRunning = false
                submit(auto: true)
            }
        }
    }

    private func submit(auto: Bool = false) {
        // 1) lock UI
        didExpire = true
        timerIsRunning = false

        // 2) call your existing submission pipeline
        // e.g. weeklyManager.submitQuiz(answers: selectedAnswers)
        // Add a flag if you want: source = auto ? "timer" : "user"
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Replace this with your real quiz view.
/// isLocked should disable taps / changes when true.
struct QuizContentView: View {
    @Binding var selectedAnswers: [Int?]
    let isLocked: Bool

    var body: some View {
        Text("Your existing quiz UI here")
            .opacity(isLocked ? 0.6 : 1.0)
    }
}
