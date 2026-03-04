//
//  TAFTypography.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

enum TAFTypography {
    static func largeTitle(_ weight: Font.Weight = .semibold) -> Font { .system(size: 34, weight: weight) }
    static func title(_ weight: Font.Weight = .semibold) -> Font { .system(size: 24, weight: weight) }
    static func section(_ weight: Font.Weight = .medium) -> Font { .system(size: 18, weight: weight) }
    static func body(_ weight: Font.Weight = .regular) -> Font { .system(size: 16, weight: weight) }
    static func caption(_ weight: Font.Weight = .medium) -> Font { .system(size: 13, weight: weight) }
}
