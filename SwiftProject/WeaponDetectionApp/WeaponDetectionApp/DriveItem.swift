//
//  AuthViewModel.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/7/26.
//

import Foundation

public struct DriveItem: Identifiable, Codable, Equatable
{
    public let id: String
    public let name: String
    public let webUrl: URL?
    public let thumbnailUrl: URL?

    public init(id: String, name: String, webUrl: URL? = nil, thumbnailUrl: URL? = nil)
    {
        self.id = id
        self.name = name
        self.webUrl = webUrl
        self.thumbnailUrl = thumbnailUrl
    }
}
