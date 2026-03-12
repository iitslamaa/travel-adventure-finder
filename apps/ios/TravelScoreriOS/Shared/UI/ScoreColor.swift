//
//  ScoreColor.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/12/26.
//

import SwiftUI

/// Centralized score → color mapping used across the app
struct ScoreColor {
    private static let good = Color(red: 0.12, green: 0.55, blue: 0.24)
    private static let warn = Color(red: 0.73, green: 0.58, blue: 0.06)
    private static let bad = Color(red: 0.82, green: 0.45, blue: 0.06)
    private static let danger = Color(red: 0.72, green: 0.20, blue: 0.18)

    static func background(for score: Int?) -> Color {
        guard let score = score else {
            return Color.secondary.opacity(0.1)
        }

        switch score {
        case 80...100:
            return good
        case 60..<80:
            return warn
        case 40..<60:
            return bad
        default:
            return danger
        }
    }

    static func border(for score: Int?) -> Color {
        guard let score = score else {
            return Color.secondary.opacity(0.4)
        }

        switch score {
        case 80...100:
            return good
        case 60..<80:
            return warn
        case 40..<60:
            return bad
        default:
            return danger
        }
    }
}
