//
//  AuthViewModel.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/7/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject
{
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var displayName: String = ""

    func restoreSessionIfPossible() async
    {
        let savedName = UserDefaults.standard.string(forKey: "savedDisplayName")
        let savedSignedIn = UserDefaults.standard.bool(forKey: "isSignedIn")

        if savedSignedIn, let savedName
        {
            self.displayName = savedName
            self.isSignedIn = true
        }
    }

    func signIn() async
    {
        isLoading = true
        errorMessage = nil

        do
    {
            try await Task.sleep(nanoseconds: 800_000_000)

            let fakeName = "Signed In User"
            self.displayName = fakeName
            self.isSignedIn = true

            UserDefaults.standard.set(true, forKey: "isSignedIn")
            UserDefaults.standard.set(fakeName, forKey: "savedDisplayName")
        } catch {
            errorMessage = "Sign-in failed. Please try again."
        }

        isLoading = false
    }

    func signOut() {
        isSignedIn = false
        displayName = ""
        errorMessage = nil

        UserDefaults.standard.removeObject(forKey: "savedDisplayName")
        UserDefaults.standard.set(false, forKey: "isSignedIn")
    }
}
