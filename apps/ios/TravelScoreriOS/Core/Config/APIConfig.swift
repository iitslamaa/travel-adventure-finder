//
//  APIConfig.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 1/21/26.
//

import Foundation

enum APIConfig {

    /// Optional override via Info.plist (useful for local dev or staging)
    /// Example value: http://192.168.1.100:3000
    private static var overrideBaseURLString: String? {
        Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
    }

    static var baseURL: URL {
        if let overrideBaseURLString,
           let trimmed = overrideBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
           let overrideURL = URL(string: trimmed) {
            return overrideURL
        }

        return URL(string: "https://travel-scorer.vercel.app")!
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
