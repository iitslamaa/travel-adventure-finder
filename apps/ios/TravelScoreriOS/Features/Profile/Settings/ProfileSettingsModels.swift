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
        case .beginner: return "Beginner"
        case .conversational: return "Conversational"
        case .fluent: return "Fluent"
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
        case .solo: return "Solo"
        case .group: return "Group"
        case .both: return "Solo + Group"
        }
    }
}

enum TravelStyle: String, CaseIterable, Identifiable {
    case budget, comfortable, inBetween, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .budget: return "Budget"
        case .comfortable: return "Comfortable"
        case .inBetween: return "Between Budget and Comfy"
        case .both: return "Budget or comfy, depending"
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
