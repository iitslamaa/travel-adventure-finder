//
//  CountryVisaHelpers.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation

enum CountryVisaHelpers {

    static func headline(for country: Country, passportLabel: String) -> String {
        guard let type = country.visaType else {
            return String(localized: "country_detail.visa.headline.limited")
        }

        switch type {
        case "own_passport":
            return String(localized: "country_detail.visa.headline.own_passport")
        case "freedom_of_movement":
            return String(format: String(localized: "country_detail.visa.headline.freedom_of_movement"), passportLabel)
        case "visa_free":
            return String(format: String(localized: "country_detail.visa.headline.visa_free"), passportLabel)
        case "voa":
            return String(localized: "country_detail.visa.headline.voa")
        case "evisa":
            return String(localized: "country_detail.visa.headline.evisa")
        case "entry_permit":
            return String(localized: "country_detail.visa.headline.entry_permit")
        case "visa_required":
            return String(localized: "country_detail.visa.headline.visa_required")
        case "ban":
            return String(localized: "country_detail.visa.headline.ban")
        default:
            return String(localized: "country_detail.visa.headline.varies")
        }
    }

    static func body(for country: Country, passportLabel: String) -> String {
        if let notes = country.visaNotes, !notes.isEmpty {
            return notes
        }

        guard let type = country.visaType else {
            return String(localized: "country_detail.visa.body.limited")
        }

        switch type {
        case "own_passport":
            return String(localized: "country_detail.visa.body.own_passport")
        case "freedom_of_movement":
            return String(format: String(localized: "country_detail.visa.body.freedom_of_movement"), passportLabel)
        case "visa_free":
            return String(localized: "country_detail.visa.body.visa_free")
        case "voa":
            return String(localized: "country_detail.visa.body.voa")
        case "evisa":
            return String(localized: "country_detail.visa.body.evisa")
        case "entry_permit":
            return String(localized: "country_detail.visa.body.entry_permit")
        case "visa_required":
            return String(localized: "country_detail.visa.body.visa_required")
        case "ban":
            return String(localized: "country_detail.visa.body.ban")
        default:
            return String(localized: "country_detail.visa.body.varies")
        }
    }
}
