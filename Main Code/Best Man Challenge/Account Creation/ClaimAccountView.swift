//
//  ClaimAccountView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/1/26.
//

import SwiftUI
import FirebaseAuth

struct ClaimAccountView: View {
    @StateObject private var manager = AccountClaimManager()

    @State private var isSigningIn = false

    @State private var accountId = ""
    @State private var claimCode = ""
    @State private var email = ""
    @State private var password = ""

    @State private var signInError: String?

    var body: some View {
        VStack(spacing: 14) {

            Text(isSigningIn ? "Sign In" : "Claim Your Account")
                .font(.title2)
                .bold()

            if !isSigningIn {
                TextField("Account ID (ex: matthewp)", text: $accountId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                TextField("Claim Code (ex: A7K2-9QPD)", text: $claimCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password (6+ chars)", text: $password)
                .textFieldStyle(.roundedBorder)

            if let err = manager.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            if let err = signInError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button {
                Task {
                    if isSigningIn {
                        await signIn()
                    } else {
                        await manager.claim(
                            accountId: accountId,
                            claimCode: claimCode,
                            email: email,
                            password: password
                        )
                    }
                }
            } label: {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(buttonDisabled)

            Button {
                withAnimation {
                    isSigningIn.toggle()
                    manager.errorMessage = nil
                    signInError = nil
                }
            } label: {
                Text(isSigningIn
                     ? "Need to claim your account?"
                     : "Already claimed? Sign in")
                    .font(.footnote)
                    .foregroundStyle(Color.accent)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private var buttonTitle: String {
        if isSigningIn {
            return "Sign In"
        } else {
            return manager.isWorking ? "Claiming..." : "Claim Account"
        }
    }

    private var buttonDisabled: Bool {
        if isSigningIn {
            return email.isEmpty || password.count < 6
        } else {
            return manager.isWorking ||
                   accountId.isEmpty ||
                   claimCode.isEmpty ||
                   email.isEmpty ||
                   password.count < 6
        }
    }

    private func signIn() async {
        signInError = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            // SessionStore will pick this up automatically
        } catch {
            signInError = error.localizedDescription
        }
    }
}
