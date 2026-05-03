//
//  SharedFolderManager.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import Foundation
import Combine
import VisionKit
import Vision
import CoreML

struct DriveItem: Codable, Identifiable, Hashable, Equatable {
    let id: String
    let name: String
}

struct PendingReview: Equatable {
    let item: DriveItem
    let folderName: String
}

class SharedFolderManager: ObservableObject {
    @Published var folderID: String?
    @Published var driveID: String?
    @Published var dateFolders: [DriveItem] = []

  
    @Published var selectedFolder: DriveItem?
    @Published var imagesInSelectedFolder: [DriveItem] = []
    @Published var isLoadingImages = false
    
  
    @Published var labels: [String: String] = [:]
    @Published var labelsFileID: String?
    
    @Published var reviewQueue: [PendingReview] = []
    @Published var currentReview: PendingReview? = nil
    
    @Published var descriptions: [String: String] = [:]
    @Published var aiDescriptionsEnabled: Bool = true

    private var knownGlobalImageIDs: Set<String> = []
    private var globalWatcherTimer: Timer?

    static let shared = SharedFolderManager()

    let sharedFolderName = "ThreatDetections"
    
    // ---------------------------------------------------------
    // MARK: LOAD SHARED FOLDER (OWNER + NON-OWNER)
    // ---------------------------------------------------------
    func loadSharedFolder(token: String, userEmail: String, completion: @escaping (Bool) -> Void) {

        
        if userEmail.lowercased() == "laneevans2005100@outlook.com"
        {
            print("Owner detected — loading folder from root")

            let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/root/children")!
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req)
            { data, _, error in
                if let error = error
                {
                    print("root children error:", error)
                    completion(false)
                    return
                }

                guard let data = data else
                {
                    print("root children: no data")
                    completion(false)
                    return
                }

                print("root children raw JSON:")
                print(String(data: data, encoding: .utf8) ?? "Unable to decode")

                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let value = json["value"] as? [[String: Any]]
                else
                {
                    completion(false)
                    return
                }

                for item in value
                {
                    let name = item["name"] as? String ?? "<no name>"
                    let id = item["id"] as? String ?? "<no id>"

                    print("root item:", name, "|", id)

                    if name == self.sharedFolderName
                    {
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
            }
            .resume()

            return
        }

        // NON-OWNER BRANCH (sharedWithMe)
        print("Non-owner detected — loading from sharedWithMe")

        let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/sharedWithMe")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data
            else
            {
                completion(false)
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else
            {
                completion(false)
                return
            }

            for item in value
            {
                guard let remote = item["remoteItem"] as? [String: Any] else { continue }

                let name = remote["name"] as? String
                let id = remote["id"] as? String
                let parentRef = remote["parentReference"] as? [String: Any]
                let driveId = parentRef?["driveId"] as? String

                if name == self.sharedFolderName,
                   let id = id,
                   let driveId = driveId
                {

                    print("Shared folder matched:", name ?? "<no name>")
                    print("remoteItem.id:", id)
                    print("remoteItem.driveId:", driveId)

                    DispatchQueue.main.async
                    {
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
        }
        .resume()
    }

    // ---------------------------------------------------------
    // MARK: LOAD DATE FOLDERS
    // ---------------------------------------------------------
    func loadImages(token: String, completion: @escaping ([DriveItem]) -> Void = { _ in }) {
        guard let folderID = folderID
        else
        {
            completion([])
            return
        }

        let url: URL
        if let driveID = driveID
        {
            url = URL(string: "https://graph.microsoft.com/v1.0/drives/\(driveID)/items/\(folderID)/children")!
        }
        else
        {
            url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(folderID)/children")!
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data
            else
            {
                completion([])
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else
            {
                completion([])
                return
            }

            let folders = value.compactMap
            { dict -> DriveItem? in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String else { return nil }

                if dict["folder"] != nil
                {
                    return DriveItem(id: id, name: name)
                }
                return nil
            }

            completion(folders)

            DispatchQueue.main.async
            {
                self.dateFolders = folders
            }

        }
        .resume()
    }
    
    // ---------------------------------------------------------
    // MARK: LOAD IMAGES INSIDE DATE FOLDER
    // ---------------------------------------------------------
    func loadImagesInDateFolder(folderID: String, token: String, completion: @escaping ([DriveItem]) -> Void)
    {

        let url: URL

        
        if let driveID = driveID
        {
            url = URL(string:
                "https://graph.microsoft.com/v1.0/drives/\(driveID)/items/\(folderID)/children"
            )!
        }
        else
        {
            url = URL(string:
                "https://graph.microsoft.com/v1.0/me/drive/items/\(folderID)/children"
            )!
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else
            {
                completion([])
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = json["value"] as? [[String: Any]]
            else
            {
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

        }
        .resume()
    }

    // ---------------------------------------------------------
    // MARK: LABELS.JSON SUPPORT
    // ---------------------------------------------------------
    func loadLabels(token: String)
    {
        guard let folderID = folderID else { return }

        let base: String
        if let driveID = driveID
        {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        }
        else
        {
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

            for item in value
            {
                let name = item["name"] as? String ?? ""
                let id = item["id"] as? String ?? ""

                if name == "labels.json"
                {
                    print("Found labels.json with id:", id)
                    DispatchQueue.main.async
                    {
                        self.labelsFileID = id
                    }

                    self.downloadLabelsFile(token: token, fileID: id)
                    return
                }
            }

            print("labels.json not found, creating new one")
            self.createEmptyLabelsFile(token: token)
        }
        .resume()
    }

    private func downloadLabelsFile(token: String, fileID: String)
    {
        let base: String
        if let driveID = driveID
        {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        }
        else
        {
            base = "https://graph.microsoft.com/v1.0/me/drive"
        }

        let url = URL(string: "\(base)/items/\(fileID)/content")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { return }

            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            {
                DispatchQueue.main.async
                {
                    print("Loaded labels.json with \(dict.count) entries")
                    self.labels = dict
                }
            }
            else
            {
                print("Failed to parse labels.json, starting empty")
            }
        }
        .resume()
    }

    private func createEmptyLabelsFile(token: String)
    {
        guard let folderID = folderID else { return }

        let base: String
        if let driveID = driveID
        {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        }
        else
        {
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
               let id = json["id"] as? String
            {

                print("Created labels.json with id:", id)
                DispatchQueue.main.async
                {
                    self.labelsFileID = id
                }

                self.saveLabels(token: token)
            }
            else
            {
                print("Failed to create labels.json")
            }
        }
        .resume()
    }

    func saveLabels(token: String)
    {
        guard let fileID = labelsFileID
        else
        {
            print("saveLabels: no labelsFileID")
            return
        }

        let base: String
        if let driveID = driveID
        {
            base = "https://graph.microsoft.com/v1.0/drives/\(driveID)"
        }
        else
        {
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
        }
        .resume()
    }

    func setLabel(for path: String, value: String, token: String)
    {
        
        labels[path] = value

        
        DispatchQueue.main.async
        {
            self.saveLabels(token: token)
        }
    }


    func getLabel(for path: String) -> String?
    {
        return labels[path]
    }
    
    // ---------------------------------------------
    // MARK: - NEW: select folder + load its images
    // ---------------------------------------------
    func selectFolder(_ folder: DriveItem, token: String)
    {
        DispatchQueue.main.async
        {
            self.selectedFolder = folder
            self.isLoadingImages = true
            self.imagesInSelectedFolder = []
        }

        loadImagesInDateFolder(folderID: folder.id, token: token) { items in
            DispatchQueue.main.async
            {
                self.imagesInSelectedFolder = items
                self.isLoadingImages = false
            }
        }
    }
    
    func loadAllImages(token: String, completion: @escaping ([DriveItem]) -> Void)
    {
        guard folderID != nil else
        {
            completion([])
            return
        }

        loadImages(token: token) { folders in
            var allImages: [DriveItem] = []
            var idToFolderName: [String: String] = [:]
            let group = DispatchGroup()

            for folder in folders
            {
                let folderName = folder.name

                group.enter()
                self.loadImagesInDateFolder(folderID: folder.id, token: token) { images in
                    
                    for img in images
                    {
                        allImages.append(img)
                        idToFolderName[img.id] = folderName
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main)
            {
                let newIDs = Set(allImages.map { $0.id })

                if self.knownGlobalImageIDs.isEmpty
                {
                    self.knownGlobalImageIDs = newIDs
                    completion(allImages)
                    return
                }

                let added = newIDs.subtracting(self.knownGlobalImageIDs)

                if let newID = added.first,
                   let newImage = allImages.first(where: { $0.id == newID })
                {

                    let folderName = idToFolderName[newID] ?? ""
                    let pending = PendingReview(item: newImage, folderName: folderName)
                    self.reviewQueue.append(pending)

               
                    if self.currentReview == nil
                    {
                        self.currentReview = pending
                    }
                }

                self.knownGlobalImageIDs = newIDs

                if let selected = self.selectedFolder
                {
                    self.loadImagesInDateFolder(folderID: selected.id, token: token) { items in
                        DispatchQueue.main.async
                        {
                            self.imagesInSelectedFolder = items
                        }
                    }
                }

                completion(allImages)
            }
        }
    }
    
    func startGlobalWatcher(token: String)
    {
        globalWatcherTimer?.invalidate()

        DispatchQueue.main.async
        {
        
            self.loadAllImages(token: token) { _ in }

        
            self.globalWatcherTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                self.loadAllImages(token: token) { _ in }
            }
        }
    }
    
    func advanceReviewQueue()
    {
       
        if !reviewQueue.isEmpty
        {
            reviewQueue.removeFirst()
        }
        
        currentReview = reviewQueue.first
    }
    
    private var descriptionsURL: URL
    {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("descriptions.json")
    }

    func loadDescriptionsFromDisk()
    {
        if let data = try? Data(contentsOf: descriptionsURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data)
        {
            descriptions = dict
        }
    }

    func saveDescriptionsToDisk()
    {
        if let data = try? JSONEncoder().encode(descriptions)
        {
            try? data.write(to: descriptionsURL)
        }
    }

    func setDescription(for key: String, value: String)
    {
        descriptions[key] = value
        saveDescriptionsToDisk()
    }
    
    func detectObjects(in image: UIImage) async -> [String]
    {
        guard let cg = image.cgImage else { return [] }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg)

        do
        {
            try handler.perform([request])
            let results = request.results ?? []

          
            return results.prefix(3).map { $0.identifier }
        }
        catch
        {
            return []
        }
    }

    func generateDescription(from objects: [String]) -> String
    {
       
        if objects.isEmpty
        {
            return "No clearly identifiable objects were detected in this image. The scene may be low‑detail, obstructed, or outside the model’s recognition range."
        }

      
        let normalized = objects.map { $0.lowercased() }
        let primary = normalized.first!
        let others = Array(normalized.dropFirst())

        var sentences: [String] = []

        
        sentences.append("The most prominent object in the image appears to be a \(primary).")

        
        if !others.isEmpty
        {
            let list = others.joined(separator: ", ")
            sentences.append("Additional elements detected include: \(list).")
        }

        
        let threatKeywords = ["knife", "gun", "weapon", "blade", "scissors", "firearm", "rifle", "pistol"]

        if normalized.contains(where: { threatKeywords.contains($0) })
        {
            sentences.append("One or more objects may be associated with potential safety concerns. This does not confirm a threat, but indicates the need for closer review.")
        }

        sentences.append("This description is automatically generated and may not fully represent the scene.")

        return sentences.joined(separator: " ")
    }

    func describeImage(_ image: UIImage) async -> String
    {
        let objects = await detectObjects(in: image)
        return generateDescription(from: objects)
    }

    init()
    {
        loadDescriptionsFromDisk()
    }
}
