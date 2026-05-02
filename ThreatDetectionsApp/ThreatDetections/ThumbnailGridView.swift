//
//  ThumbnailGridView.swift
//  ThreatDetections
//
//  Created by Lane Evans and Joshua Langaman on 5/1/26.
//

import SwiftUI

struct ThumbnailGridView: View {
    @EnvironmentObject var shared: SharedFolderManager


    @State private var forceReviewPresented = false
    @State private var imageToReview: PendingReview?

    private let columns = [GridItem(.adaptive(minimum: 120))]

    var body: some View {
        contentView()
            .navigationTitle(shared.selectedFolder?.name ?? "")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        AuthManager.shared.signOut()
                        shared.folderID = nil
                        shared.dateFolders = []
                        shared.selectedFolder = nil
                        shared.imagesInSelectedFolder = []
                    }
                }
            }
            .onChange(of: shared.currentReview) { oldValue, newValue in
                if let pending = newValue {
                    imageToReview = pending
                    forceReviewPresented = true
                }
            }
            .fullScreenCover(isPresented: $forceReviewPresented) {
                if let pending = imageToReview {
                    ForcedReviewView(item: pending.item, folderName: pending.folderName)
                        .environmentObject(shared)
                }
            }
    }

    // ⭐ MUST BE INSIDE THE STRUCT
    @ViewBuilder
    private func contentView() -> some View {
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
                        NavigationLink {
                            FullImageView(
                                item: img,
                                token: AuthManager.shared.accessToken ?? "",
                                folderName: shared.selectedFolder?.name ?? ""
                            )
                        } label: {
                            ImageThumbnail(
                                item: img,
                                token: AuthManager.shared.accessToken ?? "",
                                folderName: shared.selectedFolder?.name ?? ""
                            )
                            .frame(height: 120)
                            .clipped()
                        }
                    }
                }
                .padding()
            }
        }
    }
}
