//
//  SignInView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans on 4/21/26.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var auth = AuthManager.shared
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome")
                .font(.largeTitle)
                .bold()

            Button(action: signIn) {
                Text("Sign in with Microsoft")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }

    func signIn() {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first?.rootViewController
        else { return }

        isSigningIn = true

        AuthManager.shared.signIn(presenting: root) { success in
            isSigningIn = false
        }
    }
}
