//
//  WhenToGoViewModel.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 1/22/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class WhenToGoViewModel: ObservableObject {

    static var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    @Published var selectedMonthIndex: Int = WhenToGoViewModel.currentMonth {
        didSet {
            if weightsStore.selectedMonth != selectedMonthIndex {
                weightsStore.selectedMonth = selectedMonthIndex
            }
            recalculateForSelectedMonth()
        }
    }

    @Published var selectedCountry: WhenToGoItem? = nil
    @Published private(set) var countriesForSelectedMonth: [WhenToGoItem] = []

    private let weightsStore: ScoreWeightsStore
    private let allCountries: [Country]
    private var cancellables = Set<AnyCancellable>()

    init(countries: [Country], weightsStore: ScoreWeightsStore) {
        self.allCountries = countries
        self.weightsStore = weightsStore

        weightsStore.$weights
            .sink { [weak self] _ in
                self?.recalculateForSelectedMonth()
            }
            .store(in: &cancellables)

        weightsStore.$selectedMonth
            .sink { [weak self] month in
                guard let self else { return }
                if self.selectedMonthIndex != month {
                    self.selectedMonthIndex = month
                } else {
                    self.recalculateForSelectedMonth()
                }
            }
            .store(in: &cancellables)

        self.selectedMonthIndex = weightsStore.selectedMonth

        recalculateForSelectedMonth()
    }

    var peakCountries: [WhenToGoItem] {
        countriesForSelectedMonth
            .filter { $0.seasonType == .peak }
            .sorted {
                ($0.country.score ?? Int.min) >
                ($1.country.score ?? Int.min)
            }
    }

    var shoulderCountries: [WhenToGoItem] {
        countriesForSelectedMonth
            .filter { $0.seasonType == .shoulder }
            .sorted {
                ($0.country.score ?? Int.min) >
                ($1.country.score ?? Int.min)
            }
    }

    var goodCountries: [WhenToGoItem] {
        countriesForSelectedMonth
            .filter { $0.seasonType == .good }
            .sorted {
                ($0.country.score ?? Int.min) >
                ($1.country.score ?? Int.min)
            }
    }

    var poorCountries: [WhenToGoItem] {
        countriesForSelectedMonth
            .filter { $0.seasonType == .poor }
            .sorted {
                ($0.country.score ?? Int.min) >
                ($1.country.score ?? Int.min)
            }
    }

    var peakCount: Int { peakCountries.count }
    var goodCount: Int { goodCountries.count }
    var shoulderCount: Int { shoulderCountries.count }
    var poorCount: Int { poorCountries.count }
    var totalCount: Int { peakCount + goodCount + shoulderCount + poorCount }

    func recalculateForSelectedMonth() {
        countriesForSelectedMonth = allCountries.compactMap { country -> WhenToGoItem? in
            guard let seasonType = computeSeasonType(for: country),
                  let seasonalityScore = computeSeasonalityScore(for: country)
            else { return nil }

            var adjustedCountry = country
            adjustedCountry.score = adjustedCountry.recalculatedScore(
                using: weightsStore.weights,
                selectedMonth: selectedMonthIndex
            )

            return WhenToGoItem(
                country: adjustedCountry,
                seasonType: seasonType,
                seasonalityScore: seasonalityScore
            )
        }
    }

    private func computeSeasonType(for country: Country) -> SeasonType? {
        switch country.resolvedSeasonalityLabel(for: selectedMonthIndex) {
        case "best":
            return .peak
        case "good":
            return .good
        case "shoulder":
            return .shoulder
        case "poor":
            return .poor
        default:
            return nil
        }
    }

    private func computeSeasonalityScore(for country: Country) -> Int? {
        country.resolvedSeasonalityScore(for: selectedMonthIndex)
    }
}
