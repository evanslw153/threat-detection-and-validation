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
                        if let imageURL = URL(string: "Change this link to the folder when we find out how to show it on the app.")
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

