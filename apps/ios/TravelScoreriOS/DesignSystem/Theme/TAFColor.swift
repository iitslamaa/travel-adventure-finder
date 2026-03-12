//
//  TAFColor.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

enum TAFColor {
    // MARK: - Core
    static let sand = Color(hex: 0xF4F1EC)          // app background
    static let surface = Color(hex: 0xFFFFFF)       // cards
    static let surfaceAlt = Color(hex: 0xEDE7DE)    // secondary surfaces

    static let textPrimary = Color(hex: 0x1E1E1E)
    static let textSecondary = Color(hex: 0x6A6A6A)

    // MARK: - Accents
    static let ocean = Color(hex: 0x2E6CF6)         // primary accent
    static let oceanSoft = Color(hex: 0x6FA9FF)     // gradient end
    static let gold = Color(hex: 0xE6B85C)          // highlight

    static let success = Color(hex: 0x3CB371)
    static let warning = Color(hex: 0xF4A261)
    static let danger = Color(hex: 0xFF6B6B)
}

// MARK: - Hex Color Helper
private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
