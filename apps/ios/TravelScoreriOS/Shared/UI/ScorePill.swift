//
//  ScorePill.swift
//  TravelScoreriOS
//

import SwiftUI

struct ScorePill: View {
    enum Band {
        case good      // green
        case warn      // yellow
        case bad       // orange
        case danger    // red
    }

    let score: Double
    let band: Band?

    // Default initializer (normal score-based coloring)
    init(score: Int) {
        self.score = Double(score)
        self.band = nil
    }

    init(score: Double) {
        self.score = score
        self.band = nil
    }

    // Explicit band initializer (used for affordability or any backend-driven band)
    init(score: Int, band: Band?) {
        self.score = Double(score)
        self.band = band
    }

    init(score: Double, band: Band?) {
        self.score = score
        self.band = band
    }

    var body: some View {
        Text(formattedScore)
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(resolvedColor)
            .background(
                Capsule()
                    .fill(resolvedColor.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(resolvedColor.opacity(0.45), lineWidth: 1.5)
            )
            .accessibilityLabel(String(format: String(localized: "common.score_accessibility_format"), Int(score)))
    }

    private var formattedScore: String {
        String(format: "%.0f", score)
    }

    /// Unified color resolver:
    /// - If a backend-driven band exists → use it
    /// - Otherwise fall back to canonical score buckets
    private var resolvedColor: Color {
        if let band {
            switch band {
            case .good:
                return ScoreColor.background(for: 100)
            case .warn:
                return ScoreColor.background(for: 70)
            case .bad:
                return ScoreColor.background(for: 50)
            case .danger:
                return ScoreColor.background(for: 10)
            }
        }

        return ScoreColor.background(for: Int(score))
    }
}
