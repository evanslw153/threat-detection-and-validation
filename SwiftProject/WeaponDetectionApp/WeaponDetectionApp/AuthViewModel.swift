//
//  AuthViewModel.swift
//  WeaponDetectionApp
//
//  Created by Joshua Langaman on 4/7/26.
//

import Foundation
import SwiftUI
import MSAL
import Combine


@MainActor
final class AuthViewModel: ObservableObject
{
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var displayName: String = ""
    
    private let clientID = "<THE AZURE CLIENT ID>"
    private let tenantID = "common"
    private let scopes = ["User.Read", "Files.Read"]
    
    private var application: MSALPublicClientApplication?
    
    init()
    {
        let authority = try? MSALAADAuthority(
            url: URL(string: "https://login.microsoftonline.com/\(tenantID)")!
            )
        let config = MSALPublicClientApplicationConfig(
            clientId: clientID,
            redirectUri: nil,
            authority: authority
            )
        application = try? MSALPublicClientApplication(configuration: config)
        
    }
    func restoreSessionIfPossible() async {
        guard let app = application else { return }
        
        let accounts = try? app.allAccounts()
        guard let account = accounts?.first else { return }
        
        let params = MSALSilentTokenParameters(
            scopes: scopes,
            account: account
        )
        do
        {
            let result = try await app.acquireTokenSilent(with: params)
            displayName = result.account.username ?? "User"
            isSignedIn = true
        }
        catch
        {
            isSignedIn = false
        }
    }
    func signIn () async
    {
        guard let app = application else { return }
        
        isLoading = true
        errorMessage = nil
        
        let params = MSALInteractiveTokenParameters(
        scopes: scopes,
        webviewParameters: MSALWebviewParameters(authPresentationViewController: UIApplication.shared.rootVC)
        )
        
        do
        {
            let result = try await app.acquireToken(with: params)
            displayName = result.account.username ?? "User"
            isSignedIn = true
        }
        catch
        {
            errorMessage = "Microsoft sign-in failed. Please try again."
        }
        
        isLoading = false
        
    }
    func signOut ()
    {
        guard let app = application else { return }
        let accounts = try? app.allAccounts()
        accounts?.forEach { try? app.remove($0)}
        
        isSignedIn = false
        displayName = ""
        
    }
    func accessToken() async throws -> String
    {
        guard let app = application,
              let account = try app.allAccounts().first
        else
        {
            throw URLError(.userAuthenticationRequired)
        }
        let params = MSALSilentTokenParameters(scopes: scopes, account: account)
        let result = try await app.acquireTokenSilent(with: params)
        return result.accessToken
        
    }
    
}

