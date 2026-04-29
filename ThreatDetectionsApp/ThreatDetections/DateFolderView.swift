//
//  DateFolderView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

//import SwiftUI
//
//struct DateFolderView: View
//{
//    let folder: DriveItem        // from Lane
//    let token: String            // from Lane
//
//    @EnvironmentObject var shared: SharedFolderManager
//    @State private var images: [DriveItem] = []
//    @State private var isLoading = true
//
//    let columns = [GridItem(.adaptive(minimum: 120))]
//
//    var body: some View
//    {
//        ScrollView
//        {
//            if isLoading
//            {
//                ProgressView()
//                    .padding()
//            }
//            else
//            {
//                LazyVGrid(columns: columns, spacing: 12)
//                {
//                    ForEach(images, id: \.id) { img in
//                        ImageThumbnail(item: img, token: token)
//                            .frame(height: 120)
//                            .clipped()
//                    }
//                }
//                .padding()
//            }
//        }
//        .navigationTitle(folder.name)   // Joshua’s UI + Lane’s folder name
//        .onAppear {
//            loadImages()
//        }
//    }
//
//    private func loadImages()
//    {
//        shared.loadImagesInDateFolder(folderID: folder.id, token: token) { items in
//            DispatchQueue.main.async
//            {
//                self.images = items
//                self.isLoading = false
//            }
//        }
//    }
//}

import SwiftUI

struct DateFolderView: View {
    let folder: DriveItem        // date folder (e.g. "2026-04-13")
    let token: String

    @EnvironmentObject var shared: SharedFolderManager
    @State private var images: [DriveItem] = []
    @State private var isLoading = true

    let columns = [GridItem(.adaptive(minimum: 120))]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(images, id: \.id) { img in
                        ImageThumbnail(item: img,
                                       token: token,
                                       folderName: folder.name)
                            .frame(height: 120)
                            .clipped()
                    }
                }
                .padding()
            }
        }
        .navigationTitle(folder.name)
        .onAppear {
            loadImages()
        }
    }

    private func loadImages() {
        shared.loadImagesInDateFolder(folderID: folder.id, token: token) { items in
            DispatchQueue.main.async {
                self.images = items
                self.isLoading = false
            }
        }
    }
}
