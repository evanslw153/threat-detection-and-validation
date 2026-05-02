//
//  ThumbnailGridView.swift
//  ThreatDetections
//
//  Created by Lane Evans and Joshua Langaman on 5/1/26.
//

import SwiftUI

struct ThumbnailGridView: View {
    @ObservedObject var auth = AuthManager.shared
    @EnvironmentObject var shared: SharedFolderManager

    private let columns = [GridItem(.adaptive(minimum: 120))]

    var body: some View {
        VStack {
            Group {
                if shared.selectedFolder == nil {
                    Text("Select a folder")
                        .foregroundStyle(.secondary)
                } else if shared.isLoadingImages {
                    ProgressView("Loading Images...")
                } else if shared.imagesInSelectedFolder.isEmpty {
                    Text("No images in this folder")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(shared.imagesInSelectedFolder, id: \.id) { img in
                                ImageThumbnail(
                                    item: img,
                                    token: auth.accessToken ?? "",
                                    folderName: shared.selectedFolder?.name ?? ""
                                )
                                .frame(height: 120)
                                .clipped()
                            }
                        }
                        .padding()
                    }
                    .navigationTitle(shared.selectedFolder?.name ?? "")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") {
                    auth.accessToken = nil
                    auth.userEmail = nil
                    shared.folderID = nil
                    shared.driveID = nil
                    shared.images = []
                    shared.selectedFolder = nil
                    shared.imagesInSelectedFolder = []
                }
            }
        }
    }
}
