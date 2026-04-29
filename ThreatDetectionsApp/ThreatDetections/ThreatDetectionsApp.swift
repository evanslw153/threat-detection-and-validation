//
//  ThreatDetectionsApp.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI

@main
struct YourApp: App
{
    @StateObject var shared = SharedFolderManager.shared
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environmentObject(shared)
        }
    }
}
