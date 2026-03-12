//
//  TraveledStore.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 1/24/26.
//

import Foundation
import Combine

@MainActor
final class TraveledStore: ObservableObject {
    private let instanceId = UUID()

    @Published private(set) var ids: Set<String> = [] {
        didSet {
        }
    }

    private let saveKey = "traveled_country_ids_v2_iso2"

    init() {
        load()
    }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        save()
    }
    
    func replace(with ids: Set<String>) {
        self.ids = ids
        save()
    }

    func clear() {
        ids.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            
            return
        }
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            ids = Set(decoded)
        } else {
            
        }
    }

    private func save() {
        let array = Array(ids)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: saveKey)
        } else {
            print("❌ [TraveledStore:", instanceId, "] save failed to encode")
        }
    }
}
