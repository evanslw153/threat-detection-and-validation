//
//  DashboardView.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/7/26.
//

import SwiftUI

struct DashboardView: View
{
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View
    {
        NavigationStack
        {
            VStack(spacing: 20)
            {
                Text("Welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(authViewModel.displayName)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("This is the dashboard shell.")
                    .foregroundStyle(.secondary)

                Button("Sign Out") {
                    authViewModel.signOut()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}
