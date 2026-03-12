//
//  OAuthPresenter.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/24/26.
//

import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class OAuthPresenter: NSObject {

    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in

            let authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false

            self.session = authSession

            if !authSession.start() {
                continuation.resume(throwing: URLError(.cannotLoadFromNetwork))
            }
        }
    }
}

extension OAuthPresenter: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
