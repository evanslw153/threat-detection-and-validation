//
//  WeaponDetectionAppApp.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 3/24/26.
//

import SwiftUI
import MSAL

@main
struct WeaponDetectionAppApp: App
{
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .onOpenURL
                {
                    url in MSALPublicClientApplication.handleMSALResponse( url, sourceApplication: nil)
                }
        }
        
    }
}
