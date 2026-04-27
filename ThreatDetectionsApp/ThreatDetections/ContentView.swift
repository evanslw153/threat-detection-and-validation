//
//  ContentView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var auth = AuthManager.shared

    var body: some View {
        NavigationView {
            if auth.accessToken == nil {
                SignInView()
            } else {
                ImageGridView()
            }
        }
    }
}
