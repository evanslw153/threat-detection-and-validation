//
//  FullImageView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI

struct FullImageView: View
{
    let item: DriveItem
    let token: String
    
    @EnvironmentObject var shared: SharedFolderManager
    @State private var image: UIImage?
    @State private var isLoading = true
    
    let columns = [GridItem(.adaptive(minimum: 120))]

    var body: some View
    {
        Group
        {
            if let img = image
            {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            }
            else
            {
                ProgressView("Loading...")
            }
        }
        .onAppear(perform: loadFullImage)
    }

    func loadFullImage()
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

        let url = URL(string: "\(base)/content")!

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data, let ui = UIImage(data: data)
            {
                DispatchQueue.main.async { image = ui }
            }
        }.resume()
    }
}
