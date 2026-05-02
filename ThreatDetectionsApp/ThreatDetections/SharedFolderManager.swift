//
//  SharedFolderManager.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import Foundation
import Combine

struct DriveItem: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let name: String
}

struct PendingReview: Equatable {
    let item: DriveItem
    let folderName: String
}

class SharedFolderManager: ObservableObject {
    @Published var folderID: String?          // ThreatDetections folder ID
    @Published var driveID: String?           // Drive ID (nil for owner)
    @Published var dateFolders: [DriveItem] = []

    // NEW: selection + images for selected folder
    @Published var selectedFolder: DriveItem?
    @Published var imagesInSelectedFolder: [DriveItem] = []
    @Published var isLoadingImages = false
    
    // Labels
    @Published var labels: [String: String] = [:]   // "2026-04-13/image1.jpg": "ValidThreat"
    @Published var labelsFileID: String?           // labels.json file ID
    
    @Published var reviewQueue: [PendingReview] = []
    @Published var currentReview: PendingReview? = nil

    private var knownGlobalImageIDs: Set<String> = []
    private var globalWatcherTimer: Timer?

    static let shared = SharedFolderManager()

    let sharedFolderName = "ThreatDetections"
    
    // ---------------------------------------------------------
    // MARK: LOAD SHARED FOLDER (OWNER + NON-OWNER)
    // ---------------------------------------------------------
    func loadSharedFolder(token: String, userEmail: String, completion: @escaping (Bool) -> Void) {

        // OWNER BRANCH
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

                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let value = json["value"] as? [[String: Any]]
                else {
                    completion(false)
                    return
                }

                for item in value {
                    let name = item["name"] as? String ?? "<no name>"
                    let id = item["id"] as? String ?? "<no id>"

                    print("root item:", name, "|", id)

                    if name == self.sharedFolderName {
                        print("Matched sharedFolderName:", name)

                        DispatchQueue.main.async {
                            self.folderID = id
                            self.driveID = nil   // owner uses /me/drive
                            self.loadImages(token: token)
                            self.loadLabels(token: token)
                        }

                        completion(true)
                        return
                    }
                }

                print("Owner: folder '\(self.sharedFolderName)' not found in root")
                completion(false)
            }.resume()

            return
        }

        // NON-OWNER BRANCH (sharedWithMe)
        print("Non-owner detected — loading from sharedWithMe")

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/sharedWithMe")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else {
                completion(false)
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else {
                completion(false)
                return
            }

            for item in value {
                guard let remote = item["remoteItem"] as? [String: Any] else { continue }

                let name = remote["name"] as? String
                let id = remote["id"] as? String
                let parentRef = remote["parentReference"] as? [String: Any]
                let driveId = parentRef?["driveId"] as? String

                if name == self.sharedFolderName,
                   let id = id,
                   let driveId = driveId {

                    print("Shared folder matched:", name ?? "<no name>")
                    print("remoteItem.id:", id)
                    print("remoteItem.driveId:", driveId)

                    DispatchQueue.main.async {
                        self.folderID = id
                        self.driveID = driveId
                        self.loadImages(token: token)
                        self.loadLabels(token: token)
                    }

                    completion(true)
                    return
                }
            }

            print("Shared user: folder not found in sharedWithMe")
            completion(false)
        }.resume()
    }

    // ---------------------------------------------------------
    // MARK: LOAD DATE FOLDERS
    // ---------------------------------------------------------
    func loadImages(token: String, completion: @escaping ([DriveItem]) -> Void = { _ in }) {
        guard let folderID = folderID else {
            completion([])
            return
        }

        let url: URL
        if let driveID = driveID {
            url = URL(string: "https://graph.microsoft.com/v1.0/drives/\(driveID)/items/\(folderID)/children")!
        } else {
            url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(folderID)/children")!
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else {
                completion([])
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else {
                completion([])
                return
            }

            let folders = value.compactMap { dict -> DriveItem? in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String else { return nil }

                if dict["folder"] != nil {
                    return DriveItem(id: id, name: name)
                }
                return nil
            }

            completion(folders)

            DispatchQueue.main.async {
                // This drives your navigation pane
                self.dateFolders = folders
            }

        }.resume()
    }
    
    // ---------------------------------------------------------
    // MARK: LOAD IMAGES INSIDE DATE FOLDER
    // ---------------------------------------------------------
    func loadImagesInDateFolder(folderID: String, token: String, completion: @escaping ([DriveItem]) -> Void) {

        let url: URL

        if let driveID = driveID {
            url = URL(string:
                "https://graph.microsoft.com/v1.0/drives/\(driveID)/items/\(folderID)/children"
            )!
        } else {
            url = URL(string:
                "https://graph.microsoft.com/v1.0/me/drive/items/\(folderID)/children"
            )!
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else {
                completion([])
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else {
                completion([])
                return
            }

            let items = value.compactMap { dict -> DriveItem? in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String else { return nil }

                if dict["file"] != nil {
                    return DriveItem(id: id, name: name)
                }
                return nil
            }

            completion(items)

        }.resume()
    }

    // ---------------------------------------------------------
    // MARK: LABELS.JSON SUPPORT
    // ---------------------------------------------------------
    func loadLabels(token: String) {
        guard let folderID = folderID else { return }

        let base: String
        if let driveID = driveID {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        } else {
            base = "https://graph.microsoft.com/v1.0/me/drive"
        }

        let url = URL(string: "\(base)/items/\(folderID)/children")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { return }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else { return }

            for item in value {
                let name = item["name"] as? String ?? ""
                let id = item["id"] as? String ?? ""

                if name == "labels.json" {
                    print("Found labels.json with id:", id)
                    DispatchQueue.main.async {
                        self.labelsFileID = id
                    }

                    self.downloadLabelsFile(token: token, fileID: id)
                    return
                }
            }

            print("labels.json not found, creating new one")
            self.createEmptyLabelsFile(token: token)
        }.resume()
    }

    private func downloadLabelsFile(token: String, fileID: String) {
        let base: String
        if let driveID = driveID {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        } else {
            base = "https://graph.microsoft.com/v1.0/me/drive"
        }

        let url = URL(string: "\(base)/items/\(fileID)/content")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { return }

            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                DispatchQueue.main.async {
                    print("Loaded labels.json with \(dict.count) entries")
                    self.labels = dict
                }
            } else {
                print("Failed to parse labels.json, starting empty")
            }
        }.resume()
    }

    private func createEmptyLabelsFile(token: String) {
        guard let folderID = folderID else { return }

        let base: String
        if let driveID = driveID {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        } else {
            base = "https://graph.microsoft.com/v1.0/me/drive"
        }

        let url = URL(string: "\(base)/items/\(folderID)/children")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "name": "labels.json",
            "file": [:]
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["id"] as? String {

                print("Created labels.json with id:", id)
                DispatchQueue.main.async {
                    self.labelsFileID = id
                }

                self.saveLabels(token: token)
            } else {
                print("Failed to create labels.json")
            }
        }.resume()
    }

    func saveLabels(token: String) {
        guard let fileID = labelsFileID else {
            print("saveLabels: no labelsFileID")
            return
        }

        let base: String
        if let driveID = driveID {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        } else {
            base = "https://graph.microsoft.com/v1.0/me/drive"
        }

        let url = URL(string: "\(base)/items/\(fileID)/content")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        req.httpBody = try? JSONSerialization.data(withJSONObject: labels)

        URLSession.shared.dataTask(with: req) { _, _, _ in
            print("labels.json saved")
        }.resume()
    }

    func setLabel(for path: String, value: String, token: String) {
        // Update immediately (safe)
        labels[path] = value

        // Save AFTER the view finishes updating
        DispatchQueue.main.async {
            self.saveLabels(token: token)
        }
    }


    func getLabel(for path: String) -> String? {
        return labels[path]
    }
    
    // MARK: - NEW: select folder + load its images
    func selectFolder(_ folder: DriveItem, token: String) {
        DispatchQueue.main.async {
            self.selectedFolder = folder
            self.isLoadingImages = true
            self.imagesInSelectedFolder = []
        }

        loadImagesInDateFolder(folderID: folder.id, token: token) { items in
            DispatchQueue.main.async {
                self.imagesInSelectedFolder = items
                self.isLoadingImages = false
            }
        }
    }
    
    func loadAllImages(token: String, completion: @escaping ([DriveItem]) -> Void) {
        guard folderID != nil else {
            completion([])
            return
        }

        loadImages(token: token) { folders in
            var allImages: [DriveItem] = []
            var idToFolderName: [String: String] = [:]   // ⭐ track which image belongs to which folder
            let group = DispatchGroup()

            for folder in folders {
                let folderName = folder.name

                group.enter()
                self.loadImagesInDateFolder(folderID: folder.id, token: token) { images in
                    // collect images and map IDs → folder name
                    for img in images {
                        allImages.append(img)
                        idToFolderName[img.id] = folderName
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let newIDs = Set(allImages.map { $0.id })

                // ⭐ FIRST RUN: initialize known IDs and skip detection
                if self.knownGlobalImageIDs.isEmpty {
                    self.knownGlobalImageIDs = newIDs
                    completion(allImages)
                    return
                }

                let added = newIDs.subtracting(self.knownGlobalImageIDs)

                if let newID = added.first,
                   let newImage = allImages.first(where: { $0.id == newID }) {

                    let folderName = idToFolderName[newID] ?? ""
                    let pending = PendingReview(item: newImage, folderName: folderName)
                    self.reviewQueue.append(pending)

                    // If nothing is being reviewed, start immediately
                    if self.currentReview == nil {
                        self.currentReview = pending
                    }
                }

                self.knownGlobalImageIDs = newIDs

                if let selected = self.selectedFolder {
                    self.loadImagesInDateFolder(folderID: selected.id, token: token) { items in
                        DispatchQueue.main.async {
                            self.imagesInSelectedFolder = items
                        }
                    }
                }

                completion(allImages)
            }
        }
    }
    
    func startGlobalWatcher(token: String) {
        globalWatcherTimer?.invalidate()

        DispatchQueue.main.async {
            // fire once immediately
            self.loadAllImages(token: token) { _ in }

            // then poll every 5 seconds
            self.globalWatcherTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                self.loadAllImages(token: token) { _ in }
            }
        }
    }
    
    func advanceReviewQueue() {
        // Remove the item that was just reviewed
        if !reviewQueue.isEmpty {
            reviewQueue.removeFirst()
        }

        // Move to the next item, or clear if none left
        currentReview = reviewQueue.first
    }
}
