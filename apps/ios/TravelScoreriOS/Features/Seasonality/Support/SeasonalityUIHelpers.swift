//
//  SeasonalityUIHelpers.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 12/2/25.
//

import Foundation
import SwiftUI

struct MonthMeta: Identifiable {
    let id: Int        // 1...12
    let label: String  // "January"
    let short: String  // "Jan"
}

let allMonthsMeta: [MonthMeta] = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent

    return zip(formatter.monthSymbols, formatter.shortMonthSymbols)
        .enumerated()
        .map { index, names in
            MonthMeta(id: index + 1, label: names.0, short: names.1)
        }
}()

func scoreTone(_ value: Double?) -> Color {
    guard let value else { return Color(.systemGray5) }
    switch value {
    case 80...:
        return Color(.systemGreen)
    case 60...:
        return Color(.systemYellow)
    case 0...:
        return Color(.systemRed)
    default:
        return Color(.black)
    }
}

func scoreBackground(_ value: Double?) -> Color {
    guard let value else { return Color(.systemGray6) }
    switch value {
    case 80...:
        return Color(.systemGreen).opacity(0.15)
    case 60...:
        return Color(.systemYellow).opacity(0.15)
    case 0...:
        return Color(.systemRed).opacity(0.15)
    default:
        return Color.black
    }
}
