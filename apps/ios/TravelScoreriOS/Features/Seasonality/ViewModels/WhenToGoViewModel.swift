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

    struct SeasonSection: Identifiable, Hashable {
        let seasonType: SeasonType
        let title: String
        let note: String
        let countries: [WhenToGoItem]

        var id: SeasonType { seasonType }
    }

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
    @Published private(set) var seasonSections: [SeasonSection] = []

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

    var peakCount: Int { seasonSections.first(where: { $0.seasonType == .peak })?.countries.count ?? 0 }
    var goodCount: Int { seasonSections.first(where: { $0.seasonType == .good })?.countries.count ?? 0 }
    var shoulderCount: Int { seasonSections.first(where: { $0.seasonType == .shoulder })?.countries.count ?? 0 }
    var poorCount: Int { seasonSections.first(where: { $0.seasonType == .poor })?.countries.count ?? 0 }
    var totalCount: Int { countriesForSelectedMonth.count }

    func recalculateForSelectedMonth() {
        let items = allCountries.compactMap { country -> WhenToGoItem? in
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

        countriesForSelectedMonth = items
        seasonSections = buildSections(from: items)
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

    private func buildSections(from items: [WhenToGoItem]) -> [SeasonSection] {
        let grouped = Dictionary(grouping: items, by: \.seasonType)

        return [
            SeasonSection(
                seasonType: .peak,
                title: "Peak season",
                note: "Best weather and overall conditions. Expect the busiest stretch, higher prices, and the strongest all-around travel scores.",
                countries: sortedCountries(in: grouped[.peak] ?? [])
            ),
            SeasonSection(
                seasonType: .good,
                title: "Good season",
                note: "Strong month to go with reliable conditions, but usually a little less perfect than the absolute best window.",
                countries: sortedCountries(in: grouped[.good] ?? [])
            ),
            SeasonSection(
                seasonType: .shoulder,
                title: "Shoulder season",
                note: "A balanced middle ground. You may trade some ideal weather for lighter crowds, lower prices, or a more flexible trip.",
                countries: sortedCountries(in: grouped[.shoulder] ?? [])
            ),
            SeasonSection(
                seasonType: .poor,
                title: "Rough season",
                note: "This month is usually harder for travel here. Weather, crowds, closures, or value may all work against the trip.",
                countries: sortedCountries(in: grouped[.poor] ?? [])
            ),
        ]
        .filter { !$0.countries.isEmpty }
    }

    private func sortedCountries(in items: [WhenToGoItem]) -> [WhenToGoItem] {
        items.sorted {
            ($0.country.score ?? Int.min) > ($1.country.score ?? Int.min)
        }
    }
}
