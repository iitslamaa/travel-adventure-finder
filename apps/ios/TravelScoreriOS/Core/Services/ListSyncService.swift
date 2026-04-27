//
//  ListSyncService.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/6/26.
//

import Foundation
import Supabase
import PostgREST

@MainActor
final class ListSyncService {

    private let instanceId = UUID()

    private let supabase: SupabaseManager

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    // MARK: - Fetch

    func fetchBucketList(userId: UUID) async throws -> Set<String> {
        SocialFeedDebug.log("list_sync.fetch_bucket.start instance=\(instanceId.uuidString) user=\(userId.uuidString)")
        let rows: [[String: String]] = try await supabase.client
            .from("user_bucket_list")
            .select("country_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let bucket = Set(rows.compactMap { $0["country_id"] })
        SocialFeedDebug.log(
            "list_sync.fetch_bucket.success instance=\(instanceId.uuidString) user=\(userId.uuidString) rows=\(rows.count) \(SocialFeedDebug.countrySetSummary(bucket))"
        )
        return bucket
    }

    func fetchTraveled(userId: UUID) async throws -> Set<String> {
        let rows: [[String: String]] = try await supabase.client
            .from("user_traveled")
            .select("country_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return Set(rows.compactMap { $0["country_id"] })
    }

    // MARK: - Mutations

    func setBucket(
        userId: UUID,
        countryId: String,
        add: Bool
    ) async {
        SocialFeedDebug.log(
            "list_sync.set_bucket.start instance=\(instanceId.uuidString) user=\(userId.uuidString) country=\(countryId) add=\(add)"
        )
        do {
            if add {
                try await supabase.client
                    .from("user_bucket_list")
                    .insert([
                        "user_id": userId.uuidString,
                        "country_id": countryId
                    ])
                    .execute()
            } else {
                try await supabase.client
                    .from("user_bucket_list")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("country_id", value: countryId)
                    .execute()
            }
            SocialFeedDebug.log(
                "list_sync.set_bucket.success instance=\(instanceId.uuidString) user=\(userId.uuidString) country=\(countryId) add=\(add)"
            )
        } catch {
            if add,
               let pg = error as? PostgrestError,
               pg.code == "23505" {
                SocialFeedDebug.log(
                    "list_sync.set_bucket.duplicate instance=\(instanceId.uuidString) user=\(userId.uuidString) country=\(countryId)"
                )
                return
            }
            SocialFeedDebug.log(
                "list_sync.set_bucket.error instance=\(instanceId.uuidString) user=\(userId.uuidString) country=\(countryId) add=\(add) error=\(SocialFeedDebug.describe(error))"
            )
        }
    }

    func setTraveled(
        userId: UUID,
        countryId: String,
        add: Bool
    ) async {
        do {
            if add {
                try await supabase.client
                    .from("user_traveled")
                    .insert([
                        "user_id": userId.uuidString,
                        "country_id": countryId
                    ])
                    .execute()
            } else {
                try await supabase.client
                    .from("user_traveled")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("country_id", value: countryId)
                    .execute()
            }
        } catch {
            if add,
               let pg = error as? PostgrestError,
               pg.code == "23505" {
                return
            }
        }
    }

    deinit {
    }
}
