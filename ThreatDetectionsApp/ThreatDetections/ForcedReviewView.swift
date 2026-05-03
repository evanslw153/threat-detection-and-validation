//
//  ForcedReviewView.swift
//  ThreatDetections
//
//  Created by Lane Evans on 5/1/26.
//

import SwiftUI

struct ForcedReviewView: View
{
    let item: DriveItem
    let folderName: String

    @EnvironmentObject var shared: SharedFolderManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var auth = AuthManager.shared

    var body: some View
    {
        FullImageView(
            item: item,
            token: auth.accessToken ?? "",
            folderName: folderName,
            onLabelSaved: { dismiss() }
        )
        .onDisappear
        {
            shared.advanceReviewQueue()
        }

    }
}
