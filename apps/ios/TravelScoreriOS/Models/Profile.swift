//
//  Profile.swift
//  TravelScoreriOS
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID

    var username: String
    var fullName: String
    var avatarUrl: String?

    // NEW: structured language storage
    struct LanguageJSON: Codable {
        var code: String
        var proficiency: String
    }

    var languages: [LanguageJSON]
    var livedCountries: [String]
    var travelStyle: [String]
    var travelMode: [String]
    var nextDestination: String?

    // NEW FIELDS
    var currentCountry: String?
    var favoriteCountries: [String]?

    var onboardingCompleted: Bool?
    var friendCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case languages
        case livedCountries = "lived_countries"
        case travelStyle = "travel_style"
        case travelMode = "travel_mode"
        case nextDestination = "next_destination"
        case currentCountry = "current_country"
        case favoriteCountries = "favorite_countries"
        case onboardingCompleted = "onboarding_completed"
        case friendCount = "friend_count"
    }

    private struct LegacyLanguageObject: Decodable {
        let name: String
        let proficiency: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)

        // Flexible decoding: support legacy string array OR JSON objects
        if let stringArray = try? container.decode([String].self, forKey: .languages) {
            languages = stringArray.map {
                LanguageJSON(code: $0, proficiency: "Fluent")
            }
        } else if let objectArray = try? container.decode([LanguageJSON].self, forKey: .languages) {
            languages = objectArray
        } else if let legacyObjects = try? container.decode([LegacyLanguageObject].self, forKey: .languages) {
            languages = legacyObjects.map {
                LanguageJSON(
                    code: $0.name,
                    proficiency: $0.proficiency ?? "Fluent"
                )
            }
        } else {
            languages = []
        }

        livedCountries = try container.decodeIfPresent([String].self, forKey: .livedCountries) ?? []
        travelStyle = try container.decodeIfPresent([String].self, forKey: .travelStyle) ?? []
        travelMode = try container.decodeIfPresent([String].self, forKey: .travelMode) ?? []
        nextDestination = try container.decodeIfPresent(String.self, forKey: .nextDestination)

        currentCountry = try container.decodeIfPresent(String.self, forKey: .currentCountry)
        favoriteCountries = try container.decodeIfPresent([String].self, forKey: .favoriteCountries)

        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
        friendCount = try container.decodeIfPresent(Int.self, forKey: .friendCount) ?? 0
    }
}
