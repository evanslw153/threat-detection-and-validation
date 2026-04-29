//
//  ImageGridView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI

struct ImageGridView: View
{
    @ObservedObject var auth = AuthManager.shared
    @EnvironmentObject var shared: SharedFolderManager

    var body: some View
    {
        Group
        {
            if shared.folderID == nil
            {
                Text("Loading shared folder...")
                    .onAppear
                {
                        if let token = auth.accessToken,
                           let email = auth.userEmail
                    {

                            shared.loadSharedFolder(token: token, userEmail: email) { success in
                                if success
                                {
                                    shared.loadImages(token: token)
                                }
                                else
                                {
                                    print("Failed to load shared folder")
                                }
                            }
                        }
                    else
                    {
                            print("No token or email")
                    }
                }
            }
            else if shared.images.isEmpty
            {
                ProgressView("Loading Folders...")
            }
            else
            {
                List(shared.images, id: \.id) { item in
                    NavigationLink(
                        destination: DateFolderView(folder: item, token: auth.accessToken!)
                    )
                    {
                        Text(item.name)
                    }
                }

            }
        }
    }
}
