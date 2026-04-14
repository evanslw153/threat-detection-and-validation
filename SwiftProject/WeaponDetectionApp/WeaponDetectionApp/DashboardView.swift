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

                NavigationLink("View Detection Photos")
                {
                    PhotosView(auth: authViewModel)
                }
                .buttonStyle(.borderedProminent)

                Button("Sign Out")
                {
                    authViewModel.signOut()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Dashboard")
            
        }
    }
}
