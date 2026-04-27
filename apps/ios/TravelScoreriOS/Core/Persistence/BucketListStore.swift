//
//  BucketListStore.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 1/23/26.
//

import Foundation
import Combine

@MainActor
final class BucketListStore: ObservableObject {
    private let instanceId = UUID()

    @Published private(set) var ids: Set<String> = [] {
        didSet {
            SocialFeedDebug.log(
                "bucket.store.state instance=\(instanceId.uuidString) old_\(SocialFeedDebug.countrySetSummary(oldValue)) new_\(SocialFeedDebug.countrySetSummary(ids))"
            )
        }
    }

    private let saveKey = "bucket_list_country_ids_v2_iso2"

    init() {
        SocialFeedDebug.log("bucket.store.init instance=\(instanceId.uuidString) key=\(saveKey)")
        load()
    }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: String) {
        SocialFeedDebug.log("bucket.store.toggle.start instance=\(instanceId.uuidString) country=\(id) before_\(SocialFeedDebug.countrySetSummary(ids))")
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        save()
    }

    func add(_ id: String) {
        SocialFeedDebug.log("bucket.store.add instance=\(instanceId.uuidString) country=\(id) before_\(SocialFeedDebug.countrySetSummary(ids))")
        ids.insert(id)
        save()
    }

    func remove(_ id: String) {
        SocialFeedDebug.log("bucket.store.remove instance=\(instanceId.uuidString) country=\(id) before_\(SocialFeedDebug.countrySetSummary(ids))")
        ids.remove(id)
        save()
    }
    
    func replace(with ids: Set<String>) {
        guard self.ids != ids else {
            SocialFeedDebug.log(
                "bucket.store.replace.skip instance=\(instanceId.uuidString) reason=unchanged \(SocialFeedDebug.countrySetSummary(ids))"
            )
            return
        }

        SocialFeedDebug.log(
            "bucket.store.replace instance=\(instanceId.uuidString) before_\(SocialFeedDebug.countrySetSummary(self.ids)) incoming_\(SocialFeedDebug.countrySetSummary(ids))"
        )
        self.ids = ids
        save()
    }

    func clear() {
        SocialFeedDebug.log("bucket.store.clear instance=\(instanceId.uuidString) before_\(SocialFeedDebug.countrySetSummary(ids))")
        ids.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            SocialFeedDebug.log("bucket.store.load.miss instance=\(instanceId.uuidString) key=\(saveKey)")
            return
        }
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            ids = Set(decoded)
            SocialFeedDebug.log("bucket.store.load.success instance=\(instanceId.uuidString) \(SocialFeedDebug.countrySetSummary(ids))")
        } else {
            SocialFeedDebug.log("bucket.store.load.decode_failed instance=\(instanceId.uuidString) key=\(saveKey)")
        }
    }

    private func save() {
        let array = Array(ids)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: saveKey)
            SocialFeedDebug.log("bucket.store.save.success instance=\(instanceId.uuidString) \(SocialFeedDebug.countrySetSummary(ids))")
        } else {
            SocialFeedDebug.log("bucket.store.save.encode_failed instance=\(instanceId.uuidString) \(SocialFeedDebug.countrySetSummary(ids))")
        }
    }
    
    deinit {
    }
}
