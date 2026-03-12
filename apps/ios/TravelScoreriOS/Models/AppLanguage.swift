//
//  AppLanguage.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/26/26.
//

import Foundation

struct AppLanguage: Identifiable, Codable, Hashable {
    let code: String
    let displayName: String
    let base: String

    var id: String { code }
}
