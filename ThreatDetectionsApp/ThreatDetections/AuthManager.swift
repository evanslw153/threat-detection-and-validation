//
//  AuthManager.swift
//  ThreatDetectionsApp
//
//  Created by Lane Evans and Joshua Langaman on 4/21/26.
//

import Foundation
import MSAL
import Combine
import UIKit

class AuthManager: ObservableObject
{
    static let shared = AuthManager()

    @Published var accessToken: String?
    @Published var userEmail: String?
    private var applicationContext: MSALPublicClientApplication?

    private init()
    {
        do
        {
            let authorityURL = URL(string: "https://login.microsoftonline.com/common")!
            let authority = try MSALAuthority(url: authorityURL)

            let config = MSALPublicClientApplicationConfig(
                clientId: "2253625d-b695-4cb2-9c49-fd1af0c897d6",
                redirectUri: nil,
                authority: authority
            )

            applicationContext = try MSALPublicClientApplication(configuration: config)
        }
        catch
        {
            print("MSAL init error:", error)
        }
    }

    func signIn(presenting: UIViewController, completion: @escaping (Bool) -> Void)
    {
        guard let app = applicationContext
        else
        {
            completion(false)
            return
        }

        let webParams = MSALWebviewParameters(authPresentationViewController: presenting)
        let params = MSALInteractiveTokenParameters(
            scopes: ["User.Read", "Files.ReadWrite"],
            webviewParameters: webParams
        )

        app.acquireToken(with: params) { result, error in
            if let token = result?.accessToken
            {
                DispatchQueue.main.async
                {
                    self.accessToken = token
                    self.userEmail = result?.account.username
                    completion(true)
                }
            }
            else
            {
                print("Sign-in error:", error ?? "Unknown")
                completion(false)
            }
        }
    }
    
    func signOut()
    {
        DispatchQueue.main.async
        {
            self.accessToken = nil
            self.userEmail = nil
        }
    }
}
