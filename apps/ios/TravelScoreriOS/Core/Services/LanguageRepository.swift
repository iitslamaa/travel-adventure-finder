//
//  LanguageRepository.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/26/26.
//

import Foundation

final class LanguageRepository {

    static let shared = LanguageRepository()

    private(set) var allLanguages: [AppLanguage] = []

    private init() {
        loadLanguages()
    }

    private func loadLanguages() {
        guard
            let url = Bundle.main.url(forResource: "global_languages", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([AppLanguage].self, from: data)
        else {
            print("❌ Failed to load global_languages.json")
            return
        }

        self.allLanguages = decoded.sorted { $0.displayName < $1.displayName }
    }
}
