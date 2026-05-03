//
//  FolderListView.swift
//  ThreatDetections
//
//  Created by Lane Evans and Joshua Langaman on 5/1/26.
//

import SwiftUI

struct FolderListView: View
{
    @ObservedObject var auth = AuthManager.shared
    @EnvironmentObject var shared: SharedFolderManager

    var body: some View
    {
        List(shared.dateFolders, id: \.id) { item in
            Button
            {
                shared.selectedFolder = item

                if let token = auth.accessToken
                {
                    shared.selectFolder(item, token: token)
                }
            }
            label:
            {
                Text(item.name)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Folders")
    }
}
