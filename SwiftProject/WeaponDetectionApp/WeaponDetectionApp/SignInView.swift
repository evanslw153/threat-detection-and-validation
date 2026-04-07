//
//  SignInView.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/7/26.
//

import SwiftUI
import Observation


struct SignInView: View
{
    @ObservedObject var authViewModel: AuthViewModel

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

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await authViewModel.signIn()
                }
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Sign in with Microsoft")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(authViewModel.isLoading)
            .padding(.horizontal)

            Spacer()

            Text("Version 1")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
        .padding()
    }
}
