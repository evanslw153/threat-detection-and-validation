//
//  PhotosViewModel.swift.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/14/26.
//

import Foundation
import MSAL
import SwiftUI
import Combine


@MainActor
final class PhotosViewModel: ObservableObject
{
    @Published var photos: [DrivenItem] = []
    @Published var isLoading = false
    
    func load(auth: AuthViewModel) async
    {
        isLoading = true
        do
        {
            let token = try await auth.accessToken()
            photos = try await GraphService.fetchPhotos(token: token)
        }
        catch
        {
            print("Failed to load photos:", error)
        }
        isLoading = false
    }
}

