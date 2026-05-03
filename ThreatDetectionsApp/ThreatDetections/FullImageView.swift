//
//  FullImageView.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import SwiftUI



struct FullImageView: View {
    let item: DriveItem
    let token: String
    let folderName: String   // e.g. "2026-04-13"

    @EnvironmentObject var shared: SharedFolderManager
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var descriptionText: String?

    var onLabelSaved: (() -> Void)? = nil

    var body: some View
    {
        VStack
        {
            
            Text(item.name)
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity)
                .padding()

            
            HStack
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
                .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 12)
                {
                    if let text = descriptionText
                    {
                        Text(text)
                            .padding(.bottom, 4)

                        
                        Button(action:
                        {
                            if let img = image
                            {
                                Task { await regenerateDescription(for: img) }
                            }
                            
                        })
                        {
                            Text("Regenerate Description")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                    }
                    else if shared.aiDescriptionsEnabled
                    {
                        ProgressView("Generating description…")
                    }
                }
                .frame(width: 250)

            }

            
            let key = "\(folderName)/\(item.name)"
            let currentLabel = shared.getLabel(for: key) ?? "Unlabeled"

            Text("Status: \(currentLabel)")
                .font(.footnote)
                .padding(.top, 4)

            
            HStack
            {
                Button(action:
                {
                    shared.setLabel(for: key, value: "ValidThreat", token: token)
                    onLabelSaved?()
                })
                {
                    Text("Valid Threat")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }

                Button(action:
                {
                    shared.setLabel(for: key, value: "NoThreat", token: token)
                    onLabelSaved?()
                })
                {
                    Text("No Threat")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                }

                Button(action:
                {
                    shared.setLabel(for: key, value: "MislabeledThreat", token: token)
                    onLabelSaved?()
                })
                {
                    Text("Mislabeled Threat")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
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
                DispatchQueue.main.async
                {
                    image = ui
                    isLoading = false
                    Task { await loadDescription(for: ui) }
                }
            }
        }.resume()
    }

    func loadDescription(for uiImage: UIImage) async
    {
        let key = "\(folderName)/\(item.name)"

        // 1. Cache
        if let cached = shared.descriptions[key]
        {
            descriptionText = cached
            return
        }

        // 2. Toggle off → do nothing
        if !shared.aiDescriptionsEnabled { return }

        // 3. Generate via SharedFolderManager (VNClassifyImageRequest pipeline)
        let desc = await shared.describeImage(uiImage)
        descriptionText = desc
        shared.setDescription(for: key, value: desc)
    }
    
    func regenerateDescription(for uiImage: UIImage) async
    {
        let key = "\(folderName)/\(item.name)"

        // Force new description
        let desc = await shared.describeImage(uiImage)
        descriptionText = desc

        // Overwrite cache
        shared.setDescription(for: key, value: desc)
    }
}
