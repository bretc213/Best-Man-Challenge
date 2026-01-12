//
//  LoginView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/23/25.
//


import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isLoggedIn = false
    
    init() {
        if Auth.auth().currentUser != nil {
            _isLoggedIn = State(initialValue: true)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome Back")
                    .font(.largeTitle)
                    .bold()
                
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                Button(action: loginUser) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Log In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                NavigationLink("Don't have an account? Sign Up", destination: SignupView())
                    .padding(.top)
            }
            .padding()
            .fullScreenCover(isPresented: $isLoggedIn) {
                MainTabView() // go to your main app when logged in
            }
        }
    }
    
    private func loginUser() {
        errorMessage = ""
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isLoggedIn = true
            }
        }
    }
}
