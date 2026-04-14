//
//  GraphService.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/13/26.
//

import Foundation

struct DrivenItem: Identifiable, Decodable
{
    let id: String
    let name: String
    let file: FileInfo?
    let downloadUrl: String?
    
    enum CodingKeys: String, CodingKey
    {
        case id, name, file
        case downloadUrl = "@microsoft.graph.downloadUrl"
        
    }
    
}

struct FileInfo: Decodable {}

final class GraphService
{
    static func fetchPhotos(token: String) async throws -> [DrivenItem]
    {
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/root:/WeaponDetection/Photos:/children")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GraphResponse.self, from: data)
        
        return response.value.filter {$0.file != nil }
    }
}

struct GraphResponse: Decodable
{
    let value: [DrivenItem]
}
