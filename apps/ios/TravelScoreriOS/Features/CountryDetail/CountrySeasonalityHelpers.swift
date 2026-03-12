//
//  CountrySeasonalityHelpers.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation

enum CountrySeasonalityHelpers {

    static func headline(for country: Country, selectedMonth: Int? = nil) -> String {
        switch country.resolvedSeasonalityLabel(for: selectedMonth) {
        case "best":
            return "Peak time to go ✅"
        case "good":
            return "Good time to go ✅"
        case "shoulder":
            return "Shoulder season"
        case "poor":
            return "Less ideal timing"
        default:
            return "Current timing"
        }
    }

    static func body(for country: Country, selectedMonth: Int? = nil) -> String {
        if let notes = country.seasonalityNotes, !notes.isEmpty {
            return notes
        }

        switch country.resolvedSeasonalityLabel(for: selectedMonth) {
        case "best":
            return "Weather and crowd patterns are ideal for this month."
        case "good":
            return "Conditions are generally favorable for this month, with decent weather and crowds."
        case "shoulder":
            return "This month offers a decent balance of weather, crowds, and prices, with some trade-offs."
        case "poor":
            return "This month isn’t an ideal time for weather or crowds; consider different months if possible."
        default:
            return "Seasonality data is limited; timing may still be fine, but check local conditions."
        }
    }

    static func shortMonthName(for month: Int) -> String {
        let names = ["Jan","Feb","Mar","Apr","May","Jun",
                     "Jul","Aug","Sep","Oct","Nov","Dec"]
        guard (1...12).contains(month) else { return "Month" }
        return names[month - 1]
    }

    static func fullMonthName(for month: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        guard (1...12).contains(month) else { return "this month" }
        return names[month - 1]
    }
}
