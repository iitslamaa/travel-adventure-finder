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

        recalculateForSelectedMonth()
    }

    var peakCountries: [WhenToGoItem] {
        countriesForSelectedMonth
            .filter { $0.seasonType == .peak }
            .sorted {
                weightedScore(for: $0.country) >
                weightedScore(for: $1.country)
            }
    }

    var shoulderCountries: [WhenToGoItem] {
        countriesForSelectedMonth
            .filter { $0.seasonType == .shoulder }
            .sorted {
                weightedScore(for: $0.country) >
                weightedScore(for: $1.country)
            }
    }

    var peakCount: Int { peakCountries.count }
    var shoulderCount: Int { shoulderCountries.count }
    var totalCount: Int { peakCount + shoulderCount }

    func recalculateForSelectedMonth() {
        countriesForSelectedMonth = allCountries.compactMap { country -> WhenToGoItem? in
            guard let seasonType = computeSeasonType(for: country),
                  let seasonalityScore = computeSeasonalityScore(for: country)
            else { return nil }

            var adjustedCountry = country
            let computedOverall = weightedScore(for: adjustedCountry)
            adjustedCountry.score = Int(computedOverall.rounded())

            return WhenToGoItem(
                country: adjustedCountry,
                seasonType: seasonType,
                seasonalityScore: seasonalityScore
            )
        }
    }

    private func computeSeasonType(for country: Country) -> SeasonType? {
        guard let bestMonths = country.seasonalityBestMonths,
              !bestMonths.isEmpty
        else { return nil }

        if bestMonths.contains(selectedMonthIndex) {
            return .peak
        }

        if country.seasonalityScore ?? 0 > 0 {
            return .shoulder
        }

        return nil
    }

    private func computeSeasonalityScore(for country: Country) -> Int? {
        guard let bestMonths = country.seasonalityBestMonths,
              !bestMonths.isEmpty
        else { return nil }

        if bestMonths.contains(selectedMonthIndex) {
            return 100
        }

        return 0
    }

    // ✅ Pure weighted average — no multiplier
    private func weightedScore(for country: Country) -> Double {
        let weights = weightsStore.weights

        var components: [(value: Double, weight: Double)] = []

        if let advisory = country.travelSafeScore {
            components.append((Double(advisory), weights.advisory))
        }

        if let visa = country.visaEaseScore {
            components.append((Double(visa), weights.visa))
        }

        if let affordabilityScore = country.affordabilityScore {
            components.append((Double(affordabilityScore), weights.affordability))
        }

        guard !components.isEmpty else { return 0 }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedSum = components.reduce(0) { $0 + ($1.value * $1.weight) }

        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }
}
