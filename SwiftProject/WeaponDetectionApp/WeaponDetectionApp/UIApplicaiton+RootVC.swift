//
//  UIApplicaiton+RootVC.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/13/26.
//

import UIKit

extension UIApplication {
    // Returns the root view controller of the current key window if available,
    // otherwise falls back to the first window's rootViewController,
    //and finally an empty UIViewController() as a last resort.
    var rootVC: UIViewController {
        // Collect all windows from connected window scenes
        let windows = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        // Prefer the key window if present
        if let keyWindow = windows.first(where: { $0.isKeyWindow }),
           let root = keyWindow.rootViewController {
            return root
        }

        // Otherwise fall back to the first window's rootViewController
        if let root = windows.first?.rootViewController {
            return root
        }

        // Last resort
        return UIViewController()
    }
}

