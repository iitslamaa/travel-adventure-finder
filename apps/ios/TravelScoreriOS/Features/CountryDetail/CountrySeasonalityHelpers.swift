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
            return String(localized: "country_detail.seasonality.headline.best")
        case "good":
            return String(localized: "country_detail.seasonality.headline.good")
        case "shoulder":
            return String(localized: "country_detail.seasonality.headline.shoulder")
        case "poor":
            return String(localized: "country_detail.seasonality.headline.poor")
        default:
            return String(localized: "country_detail.seasonality.headline.current")
        }
    }

    static func body(for country: Country, selectedMonth: Int? = nil) -> String {
        switch country.resolvedSeasonalityLabel(for: selectedMonth) {
        case "best":
            return String(localized: "country_detail.seasonality.body.best")
        case "good":
            return String(localized: "country_detail.seasonality.body.good")
        case "shoulder":
            return String(localized: "country_detail.seasonality.body.shoulder")
        case "poor":
            return String(localized: "country_detail.seasonality.body.poor")
        default:
            return String(localized: "country_detail.seasonality.body.current")
        }
    }

    static func shortMonthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        guard (1...12).contains(month) else { return String(localized: "common.month") }
        return formatter.shortMonthSymbols[month - 1]
    }

    static func fullMonthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        guard (1...12).contains(month) else { return String(localized: "common.this_month") }
        return formatter.monthSymbols[month - 1]
    }
}
