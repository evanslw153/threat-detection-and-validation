//
//  SignInView.swift
//  WeaponDetectionApp
//
// Created by Lane Evans and Joshua Langaman on 4/21/26.

import SwiftUI

struct SignInView: View
{
    @ObservedObject var auth = AuthManager.shared
    @State private var isSigningIn = false

    var body: some View
    {
        VStack(spacing: 24)
        {
            Spacer()

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 72))
                .padding(.bottom, 8)

            Text("Weapon Detection")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in to view detection alerts and photos.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)


            Button
            {
                signIn()
            }
            label:
            {
                HStack
                {
                    if isSigningIn
                    {
                        ProgressView()
                    }
                    else
                    {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Sign in with Microsoft")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)   // <-- centers content
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)
            .padding(.horizontal)
            
            Spacer()

            Text("Version 1")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
        .padding()
    }

    private func signIn()
    {
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

