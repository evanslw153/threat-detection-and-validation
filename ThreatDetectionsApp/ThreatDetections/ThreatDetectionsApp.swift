//
//  ThreatDetectionsApp.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans on 4/21/26.
//

import SwiftUI

@main
struct YourApp: App {
    @StateObject var shared = SharedFolderManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(shared)
        }
    }
}
