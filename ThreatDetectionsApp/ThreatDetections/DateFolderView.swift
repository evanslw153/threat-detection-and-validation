//
//  DateFolderView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans on 4/21/26.
//

import SwiftUI

struct DateFolderView: View {
    let folder: DriveItem
    let token: String

    @EnvironmentObject var shared: SharedFolderManager
    @State var images: [DriveItem] = []

    var body: some View {
        List(images, id: \.id) { img in
            Text(img.name)
            ImageThumbnail(item: img, token: token)
        }
        .onAppear {
            shared.loadImagesInDateFolder(folderID: folder.id, token: token) { items in
                DispatchQueue.main.async {
                    self.images = items
                }
            }
        }
        .navigationTitle(folder.name)
    }
}
