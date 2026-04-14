//
//  Profile.swift
//  TravelScoreriOS
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID

    var username: String
    var fullName: String
    var firstName: String?
    var lastName: String?
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
    var defaultCurrencyCode: String?

    // NEW FIELDS
    var currentCountry: String?
    var favoriteCountries: [String]?

    var onboardingCompleted: Bool?
    var friendCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case languages
        case livedCountries = "lived_countries"
        case travelStyle = "travel_style"
        case travelMode = "travel_mode"
        case nextDestination = "next_destination"
        case defaultCurrencyCode = "default_currency_code"
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
        let languageRepository = LanguageRepository.shared

        func canonicalLanguage(code rawCode: String, proficiency rawProficiency: String) -> LanguageJSON {
            LanguageJSON(
                code: languageRepository.canonicalLanguageCode(for: rawCode)
                    ?? rawCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                proficiency: LanguageProficiency(storageValue: rawProficiency).storageValue
            )
        }

        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        let decodedFullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        let decodedFirstName = try container.decodeIfPresent(String.self, forKey: .firstName)?.nilIfEmpty
        let decodedLastName = try container.decodeIfPresent(String.self, forKey: .lastName)?.nilIfEmpty
        let splitName = Self.splitName(decodedFullName)
        firstName = decodedFirstName ?? splitName.firstName
        lastName = decodedLastName ?? splitName.lastName
        fullName = Self.combinedName(firstName: firstName, lastName: lastName, fallback: decodedFullName)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)

        // Flexible decoding: support legacy string array OR JSON objects
        if let stringArray = try? container.decode([String].self, forKey: .languages) {
            languages = stringArray.map {
                canonicalLanguage(code: $0, proficiency: LanguageProficiency.fluent.storageValue)
            }
        } else if let objectArray = try? container.decode([LanguageJSON].self, forKey: .languages) {
            languages = objectArray.map {
                canonicalLanguage(code: $0.code, proficiency: $0.proficiency)
            }
        } else if let legacyObjects = try? container.decode([LegacyLanguageObject].self, forKey: .languages) {
            languages = legacyObjects.map {
                canonicalLanguage(
                    code: $0.name,
                    proficiency: $0.proficiency ?? LanguageProficiency.fluent.storageValue
                )
            }
        } else {
            languages = []
        }

        livedCountries = try container.decodeIfPresent([String].self, forKey: .livedCountries) ?? []
        travelStyle = try container.decodeIfPresent([String].self, forKey: .travelStyle) ?? []
        travelMode = try container.decodeIfPresent([String].self, forKey: .travelMode) ?? []
        nextDestination = try container.decodeIfPresent(String.self, forKey: .nextDestination)
        defaultCurrencyCode = try container.decodeIfPresent(String.self, forKey: .defaultCurrencyCode)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        currentCountry = try container.decodeIfPresent(String.self, forKey: .currentCountry)
        favoriteCountries = try container.decodeIfPresent([String].self, forKey: .favoriteCountries)

        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
        friendCount = try container.decodeIfPresent(Int.self, forKey: .friendCount) ?? 0
    }

    var formattedFullName: String {
        Self.combinedName(firstName: firstName, lastName: lastName, fallback: fullName)
    }

    var displayName: String {
        let resolvedFullName = formattedFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedFullName.isEmpty {
            return resolvedFullName
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUsername.isEmpty ? "User" : trimmedUsername
    }

    var tripDisplayName: String {
        if let firstName, !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return firstName
        }

        let resolvedFullName = formattedFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedFullName.isEmpty {
            return resolvedFullName.split(separator: " ").first.map(String.init) ?? resolvedFullName
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUsername.isEmpty ? "You" : trimmedUsername
    }

    private static func combinedName(firstName: String?, lastName: String?, fallback: String) -> String {
        let pieces = [firstName?.nilIfEmpty, lastName?.nilIfEmpty].compactMap { $0 }
        if !pieces.isEmpty {
            return pieces.joined(separator: " ")
        }

        return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitName(_ fullName: String) -> (firstName: String?, lastName: String?) {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }

        let parts = trimmed.split(whereSeparator: \.isWhitespace)
        guard let first = parts.first else { return (nil, nil) }

        return (
            firstName: String(first),
            lastName: parts.dropFirst().joined(separator: " ").nilIfEmpty
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
