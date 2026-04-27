//
//  FullImageView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans on 4/21/26.
//

import SwiftUI

struct FullImageView: View {
    let item: DriveItem
    let token: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear(perform: loadFullImage)
    }

    func loadFullImage() {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(item.id)/content")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data, let ui = UIImage(data: data) {
                DispatchQueue.main.async { image = ui }
            }
        }.resume()
    }
}
