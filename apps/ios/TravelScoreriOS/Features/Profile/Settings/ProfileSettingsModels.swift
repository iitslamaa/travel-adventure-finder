//
//  ProfileSettingsModels.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation

enum LanguageProficiency: String, CaseIterable, Identifiable, Codable {
    case beginner
    case conversational
    case fluent

    var id: String { storageValue }

    init(storageValue: String) {
        switch storageValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fluent", "native", "advanced":
            self = .fluent
        case "conversational", "intermediate":
            self = .conversational
        default:
            self = .beginner
        }
    }

    var storageValue: String { rawValue }

    var label: String {
        switch self {
        case .beginner: return String(localized: "profile.settings.language.beginner")
        case .conversational: return String(localized: "profile.settings.language.conversational")
        case .fluent: return String(localized: "profile.settings.language.fluent")
        }
    }

    var compatibilityMultiplier: Double {
        switch self {
        case .beginner: return 0
        case .conversational: return 0.5
        case .fluent: return 1
        }
    }

    var normalizedScore: Int {
        switch self {
        case .beginner: return 0
        case .conversational: return 50
        case .fluent: return 100
        }
    }
}

enum TravelMode: String, CaseIterable, Identifiable {
    case solo, group, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .solo: return String(localized: "profile.settings.travel_mode.solo")
        case .group: return String(localized: "profile.settings.travel_mode.group")
        case .both: return String(localized: "profile.settings.travel_mode.both")
        }
    }
}

enum TravelStyle: String, CaseIterable, Identifiable {
    case budget, comfortable, inBetween, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .budget: return String(localized: "profile.settings.travel_style.budget")
        case .comfortable: return String(localized: "profile.settings.travel_style.comfortable")
        case .inBetween: return String(localized: "profile.settings.travel_style.in_between")
        case .both: return String(localized: "profile.settings.travel_style.both")
        }
    }
}

struct LanguageEntry: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var proficiency: String

    var canonicalCode: String {
        LanguageRepository.shared.canonicalLanguageCode(for: name)
        ?? name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var normalizedProficiency: LanguageProficiency {
        LanguageProficiency(storageValue: proficiency)
    }

    var display: String {
        "\(canonicalCode) (\(normalizedProficiency.label))"
    }
}

struct PassportPreferences: Codable, Equatable {
    var nationalityCountryCodes: [String]
    var passportCountryCode: String?

    static let empty = PassportPreferences(
        nationalityCountryCodes: [],
        passportCountryCode: nil
    )

    var effectivePassportCountryCode: String? {
        if let passportCountryCode,
           !passportCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return passportCountryCode.uppercased()
        }

        return nationalityCountryCodes.first?.uppercased()
    }
}

enum CountrySelectionFormatter {
    static func localizedName(for code: String) -> String {
        let upper = code.uppercased()
        return AppDisplayLocale.current.localizedString(forRegionCode: upper) ?? upper
    }

    static func label(for code: String) -> String {
        let upper = code.uppercased()
        return "\(flag(for: upper)) \(localizedName(for: upper))"
    }

    static func flag(for code: String) -> String {
        guard code.count == 2 else { return code }
        let base: UInt32 = 127397
        return code.unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
