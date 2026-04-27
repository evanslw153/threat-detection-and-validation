//
//  SharedFolderManager.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans on 4/21/26.
//

import Foundation
import Combine

struct DriveItem: Codable {
    let id: String
    let name: String
}

class SharedFolderManager: ObservableObject {
    @Published var folderID: String?
    @Published var images: [DriveItem] = []

    let sharedFolderName = "ThreatDetections"   // <-- CHANGE THIS TO YOUR FOLDER NAME

    func loadSharedFolder(token: String, userEmail: String, completion: @escaping (Bool) -> Void) {

        if userEmail.lowercased() == "laneevans2005100@outlook.com" {
            print("Owner detected — loading folder from root")

            let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/root/children")!
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, _, error in
                if let error = error {
                    print("root children error:", error)
                    completion(false)
                    return
                }

                guard let data = data else {
                    print("root children: no data")
                    completion(false)
                    return
                }

                print("root children raw JSON:")
                print(String(data: data, encoding: .utf8) ?? "Unable to decode")

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let value = json["value"] as? [[String: Any]] {

                    for item in value {
                        let name = item["name"] as? String ?? "<no name>"
                        let id = item["id"] as? String ?? "<no id>"
                        print("root item:", name, "|", id)

                        if name == self.sharedFolderName {
                            print("Matched sharedFolderName:", name)
                            print("Matched folder ID:", id)   // ADD THIS
                            
                            DispatchQueue.main.async {
                                self.folderID = id
                                self.loadImages(token: token)   // <-- ADD THIS
                            }
                            completion(true)
                            return
                        }
                    }
                }

                print("Owner: folder '\(self.sharedFolderName)' not found in root")
                completion(false)
            }.resume()

            return
        }



        // Otherwise, load from sharedWithMe
        print("Non-owner detected — loading from sharedWithMe")

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/sharedWithMe")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { completion(false); return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let value = json["value"] as? [[String: Any]] {

                for item in value {
                    if let remoteItem = item["remoteItem"] as? [String: Any],
                       let name = remoteItem["name"] as? String,
                       let id = remoteItem["id"] as? String,
                       name == self.sharedFolderName {

                        DispatchQueue.main.async {
                            self.folderID = id
                            self.loadImages(token: token)   // <-- ADD THIS
                        }
                        completion(true)
                        return
                    }
                }
            }

            print("Shared user: folder not found in sharedWithMe")
            completion(false)
        }.resume()
    }
    
    func loadImages(token: String) {
        guard let folderID = folderID else {
            print("loadImages: no folderID")
            return
        }
        
        print("Using folderID:", folderID)   // ADD THIS

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(folderID)/children")!
        print("loadImages URL:", url.absoluteString)

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                print("loadImages error:", error)
                return
            }

            guard let data = data else {
                print("loadImages: no data")
                return
            }

            print("Date folder list JSON:")
            print(String(data: data, encoding: .utf8) ?? "Unable to decode")

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else {
                print("loadImages: JSON parse failed")
                return
            }

            // DEBUG: log each item
            for dict in value {
                let name = dict["name"] as? String ?? "<no name>"
                let hasFolder = dict["folder"] != nil
                let hasFile = dict["file"] != nil
                print("child item:", name, "| folder:", hasFolder, "| file:", hasFile)
            }

            let items = value.compactMap { dict -> DriveItem? in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String else { return nil }

                if dict["folder"] != nil {
                    return DriveItem(id: id, name: name)
                }
                return nil
            }

            DispatchQueue.main.async {
                print("Found \(items.count) date folders")
                self.images = items
            }
        }.resume()
    }
    
    func loadImagesInDateFolder(folderID: String, token: String, completion: @escaping ([DriveItem]) -> Void) {

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(folderID)/children")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else {
                completion([])
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let value = json["value"] as? [[String: Any]] {

                let items = value.compactMap { dict -> DriveItem? in
                    guard let id = dict["id"] as? String,
                          let name = dict["name"] as? String else { return nil }

                    // Only include FILES here
                    if dict["file"] != nil {
                        return DriveItem(id: id, name: name)
                    }

                    return nil
                }

                completion(items)
            } else {
                completion([])
            }
        }.resume()
    }

}
