//
//  ImageThumbnail.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI

struct ImageThumbnail: View
{
    let item: DriveItem
    let token: String
    
    @EnvironmentObject var shared: SharedFolderManager
    @State private var image: UIImage?

    var body: some View
    {
        NavigationLink(destination: FullImageView(item: item, token: token))
        {
            Group
            {
                if let img = image
                {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                }
                else
                {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 120, height: 120)
            .clipped()
            .onAppear(perform: loadThumbnail)
        }
    }

    func loadThumbnail()
    {
        let base: String

        if let driveID = SharedFolderManager.shared.driveID
        {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)/items/\(item.id)"
        }
        else
        {
            base = "https://graph.microsoft.com/v1.0/me/drive/items/\(item.id)"
        }

        let url = URL(string: "\(base)/thumbnails/0/medium/content")!

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data, let ui = UIImage(data: data) {
                DispatchQueue.main.async { image = ui }
            }
        }.resume()
    }
}
