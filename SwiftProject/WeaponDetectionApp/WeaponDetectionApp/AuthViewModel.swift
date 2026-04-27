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

    private let clientID = "2253625d-b695-4cb2-9c49-fd1af0c897d6"
    private let tenantID = "common"
    private let scopes = ["User.Read", "Files.Read"]

    private var application: MSALPublicClientApplication?

    init()
    {
        do {
            let authority = try MSALAADAuthority(
                url: URL(string: "https://login.microsoftonline.com/\(tenantID)")!
            )

            let redirectURI = "msauth.com.evanslw153.WeaponDetectionApp://auth"

            let config = MSALPublicClientApplicationConfig(
                clientId: clientID,
                redirectUri: redirectURI,
                authority: authority
            )

            application = try MSALPublicClientApplication(configuration: config)
            print("MSAL initialized successfully")
        } catch {
            application = nil
            errorMessage = "MSAL init failed: \(error.localizedDescription)"
            print("MSAL init failed:", error)
        }
    }
    
    func restoreSessionIfPossible() async
    {
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
            print("Silent sign-in failed:", error)
        }
    }

    func signIn() async
    {
        guard let app = application else
        {
            errorMessage = "MSAL application was not created. Check client ID and redirect URI setup."
            print("signIn() aborted: application is nil")
            return
        }

        isLoading = true
        errorMessage = nil

        let params = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: MSALWebviewParameters(
                authPresentationViewController: UIApplication.shared.rootVC
            )
        )

        do {
            let result = try await app.acquireToken(with: params)
            displayName = result.account.username ?? "User"
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
            print("MSAL sign-in error:", error)
        }

        isLoading = false
    }

    func signOut()
    {
        guard let app = application else { return }
        let accounts = try? app.allAccounts()
        accounts?.forEach { try? app.remove($0) }

        isSignedIn = false
        displayName = ""
    }

    func accessToken() async throws -> String
    {
        guard let app = application,
              let account = try app.allAccounts().first
        else {
            throw URLError(.userAuthenticationRequired)
        }

        let params = MSALSilentTokenParameters(scopes: scopes, account: account)
        let result = try await app.acquireTokenSilent(with: params)
        return result.accessToken
    }
}
