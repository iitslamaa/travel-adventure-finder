//
//  CountryVisaHelpers.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation

enum CountryVisaHelpers {

    static func headline(for country: Country) -> String {
        guard let type = country.visaType else {
            return "Visa information is limited"
        }

        switch type {
        case "freedom_of_movement":
            return "Freedom of movement with US passport ✅"
        case "visa_free":
            return "Visa-free for US passport ✅"
        case "voa":
            return "Visa on arrival available"
        case "evisa":
            return "eVisa available online"
        case "entry_permit":
            return "Entry permit required"
        case "visa_required":
            return "Visa required before travel"
        case "ban":
            return "Entry heavily restricted"
        default:
            return "Visa rules vary"
        }
    }

    static func body(for country: Country) -> String {
        if let notes = country.visaNotes, !notes.isEmpty {
            return notes
        }

        guard let type = country.visaType else {
            return "Check official sources for the latest entry requirements."
        }

        switch type {
        case "freedom_of_movement":
            return "This destination is part of a territory arrangement where US passport holders can move freely without visa limits."
        case "visa_free":
            return "You can typically enter without arranging a visa in advance, subject to time limits."
        case "voa":
            return "Visa is issued on arrival; expect to handle paperwork and possible fees at the border."
        case "evisa":
            return "You’ll usually need to apply and pay online before travel."
        case "entry_permit":
            return "You may need advance authorization or a permit before entry is approved."
        case "visa_required":
            return "You must secure a visa in advance through a consulate or official channel."
        case "ban":
            return "Current rules may severely limit or ban entry; check official guidance before planning."
        default:
            return "Entry rules may depend on your trip details; confirm with official government sources."
        }
    }
}
