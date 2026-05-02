//
//  ContentView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var auth = AuthManager.shared
    @EnvironmentObject var shared: SharedFolderManager

    var body: some View {
        Group {
            if auth.accessToken == nil {
                SignInView()
            } else if shared.folderID == nil {
                // ⭐ RESTORED LOADING SCREEN
                VStack(spacing: 20) {
                    ProgressView("Loading Folders...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                .onAppear {
                    loadRootIfNeeded()
                }
            } else {
                NavigationSplitView(
                    sidebar: { FolderListView() },
                    detail: {
                        NavigationStack {
                            ThumbnailGridView()
                        }
                    }
                )
            }
        }
    }

    private func loadRootIfNeeded() {
        guard shared.folderID == nil,
              let token = auth.accessToken,
              let email = auth.userEmail else { return }

        shared.loadSharedFolder(token: token, userEmail: email) { success in
            if success {
                shared.loadImages(token: token)
                
                shared.startGlobalWatcher(token: token)
            }
        }
    }
}

