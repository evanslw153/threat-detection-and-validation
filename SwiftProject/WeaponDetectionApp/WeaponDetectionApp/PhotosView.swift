//
//  PhotosView.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/14/26.
//

import SwiftUI

struct PhotosView: View
{
    @ObservedObject var auth: AuthViewModel
    @StateObject private var vm = PhotosViewModel()
    
    let columns = [GridItem(.adaptive(minimum: 120))]
    
    var body: some View
    {
        ScrollView
        {
            if vm.isLoading
            {
                ProgressView()
            }
            else
            {
                LazyVGrid(columns: columns, spacing: 12)
                {
                    ForEach(vm.photos, id: \.id) { photo in
                        if let imageURL = URL(string: "https://onedrive.live.com/?id=%2Fpersonal%2F9f3712efaee9292b%2FDocuments%2FThreatDetections&viewid=2429d58e%2D9f65%2D41f4%2D9ef1%2De163800f5fc4&view=0")
                        {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 120)
                            .clipped()
                        }
                    }
                }
                .padding()
            }
        }
        .task
        {
            await vm.load(auth: auth)
        }
        .navigationTitle("Detection Photos")
    }
}

