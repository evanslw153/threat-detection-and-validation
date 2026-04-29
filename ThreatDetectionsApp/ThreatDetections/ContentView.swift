//
//  ContentView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI

struct ContentView: View
{
    @ObservedObject var auth = AuthManager.shared

    var body: some View
    {
        Group
        {
            if auth.accessToken == nil
            {
                SignInView()
            }
            else
            {
                NavigationStack
                {
                    ImageGridView()
                }
                
            }
        }
    }
}
