//
//  ContentView.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/7/26.
//

import SwiftUI

struct ContentView: View
{
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View
    {
        Group
        {
            if authViewModel.isSignedIn
            {
                DashboardView(authViewModel: authViewModel)
            } else {
                SignInView(authViewModel: authViewModel)
            }
        }
        .task
        {
            await authViewModel.restoreSessionIfPossible()
        }
    }
}


