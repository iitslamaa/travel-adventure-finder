//
//  SeasonalityViewModel.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 12/2/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SeasonalityViewModel: ObservableObject {

    @Published var selectedMonth: Int
    @Published var peakCountries: [SeasonalityCountry]
    @Published var shoulderCountries: [SeasonalityCountry]
    @Published var selectedCountry: SeasonalityCountry?

    @Published var isLoading: Bool
    @Published var loadError: String?

    private let service: SeasonalityService
    private let metadataResolver: CountryMetadataResolver

    // MARK: - Local-first cache for seasonality (per-month)

    private func applyCachedSeasonalityIfAvailable(forMonth month: Int) {
        guard let cached = SeasonalityCache.load(month: month) else { return }

        selectedMonth = cached.month

        // Enrich cached lists if we already have meta; otherwise show cached as-is
        let peak = metadataResolver.enrich(cached.peak)
        let shoulder = metadataResolver.enrich(cached.shoulder)

        peakCountries = peak
        shoulderCountries = shoulder

        if selectedCountry == nil {
            selectedCountry = peak.first ?? shoulder.first
        }

        loadError = nil
    }



    init(
        service: SeasonalityService,
        metadataResolver: CountryMetadataResolver,
        initialMonth: Int = Calendar.current.component(.month, from: Date())
    ) {
        self.service = service
        self.metadataResolver = metadataResolver
        self.selectedMonth = initialMonth
        self.peakCountries = []
        self.shoulderCountries = []
        self.selectedCountry = nil
        self.isLoading = false
        self.loadError = nil
    }

    convenience init(initialMonth: Int = Calendar.current.component(.month, from: Date())) {
        self.init(
            service: SeasonalityService(),
            metadataResolver: CountryMetadataResolver(),
            initialMonth: initialMonth
        )
    }

    func loadInitial() {
        Task {
            // 0) Load cached seasonality for the initial month immediately (offline/fast)
            applyCachedSeasonalityIfAvailable(forMonth: selectedMonth)

            // 1) Load country meta (names/scores) from cache if possible, then from network
            await metadataResolver.loadIfNeeded()

            // 2) Load seasonality (will use cache + refresh)
            await load(forMonth: selectedMonth)
        }
    }


    func load(forMonth month: Int) async {
        // 0) Show cached month results immediately (even if offline)
        applyCachedSeasonalityIfAvailable(forMonth: month)
        selectedMonth = month

        // If we have cached data and we're within cooldown, don't spam network
        if !SeasonalityCache.shouldRefresh(month: month, minInterval: 60) {
            return
        }

        // Show spinner only if we don't have anything to show yet
        if peakCountries.isEmpty && shoulderCountries.isEmpty {
            isLoading = true
        } else {
            isLoading = false
        }
        loadError = nil

        do {
            // Ensure we have country names/scores to display
            await metadataResolver.loadIfNeeded()

            let response = try await service.fetchSeasonality(forMonth: month)
            selectedMonth = response.month

            let enrichedPeak = metadataResolver.enrich(response.peak)
            let enrichedShoulder = metadataResolver.enrich(response.shoulder)

            peakCountries = enrichedPeak
            shoulderCountries = enrichedShoulder

            // Cache the raw seasonality result (as a lightweight Codable payload)
            SeasonalityCache.save(month: response.month, peak: response.peak, shoulder: response.shoulder)

            // Reset selection when month changes
            if let first = enrichedPeak.first {
                selectedCountry = first
            } else {
                selectedCountry = enrichedShoulder.first
            }
        } catch {
            // If we already showed cached data, keep it and show a soft error
            if peakCountries.isEmpty && shoulderCountries.isEmpty {
                loadError = error.localizedDescription
            } else {
#if DEBUG
#endif
            }
        }

        isLoading = false
    }

    func select(_ country: SeasonalityCountry) {
        selectedCountry = country
    }
}

// MARK: - Convenience init for enrichment

extension SeasonalityCountry {
    /// Memberwise initializer used by SeasonalityViewModel when enriching API results
    /// with metadata (name/score/region). This exists because we added a custom
    /// `init(from:)` in SeasonalityModels.swift, which removes the synthesized init.
    init(
        isoCode: String,
        name: String?,
        score: Double?,
        region: String?,
        scores: ScoreSnapshot?
    ) {
        self.isoCode = isoCode
        self.name = name
        self.score = score
        self.region = region
        self.scores = scores
    }
}
