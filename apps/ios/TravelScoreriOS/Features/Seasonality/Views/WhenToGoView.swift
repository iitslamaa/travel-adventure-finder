//
//  WhenToGoView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 12/2/25.
//

import Foundation
import SwiftUI

struct WhenToGoView: View {
    @StateObject private var viewModel: WhenToGoViewModel
    
    init(countries: [Country], weightsStore: ScoreWeightsStore) {
        _viewModel = StateObject(
            wrappedValue: WhenToGoViewModel(
                countries: countries,
                weightsStore: weightsStore
            )
        )
    }
    
    @State private var isDrawerOpen: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                monthScroller
                content
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .sheet(isPresented: $isDrawerOpen) {
                if let selected = viewModel.selectedCountry {
                    NavigationStack {
                        WhenToGoCountryDrawerView(country: selected)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .background(
                Image("whentogo")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            )
        }
    }
    
    private var monthScroller: some View {
        ZStack {
            Image("title_background")
                .resizable()
                .scaledToFill()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(allMonthsMeta) { month in
                        MonthChip(
                            month: month,
                            isSelected: viewModel.selectedMonthIndex == month.id
                        ) {
                            viewModel.selectedMonthIndex = month.id
                        }
                    }
                }
                .padding(.horizontal, 70)
            }
        }
        .frame(height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    countryListSection(
                        title: "Peak season",
                        note: "Best weather and overall conditions — usually the busiest and priciest.",
                        countries: viewModel.peakCountries.sorted { ($0.country.score ?? Int.min) > ($1.country.score ?? Int.min) }
                    )
                    
                    countryListSection(
                        title: "Shoulder season",
                        note: "Still good conditions, often fewer crowds and better value.",
                        countries: viewModel.shoulderCountries.sorted { ($0.country.score ?? Int.min) > ($1.country.score ?? Int.min) }
                    )
                }
            }
        }
        .refreshable {
            viewModel.recalculateForSelectedMonth()
        }
    }
    
    private func countryListSection(
        title: String,
        note: String,
        countries: [WhenToGoItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            
            if countries.isEmpty {
                Text("No destinations in this category for the selected month.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                WrapChips(countries: countries) { country in
                    viewModel.selectedCountry = country
                    isDrawerOpen = true
                }
            }
        }
        .padding()
    }
}

private struct MonthChip: View {
    let month: MonthMeta
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(month.short)
            .font(.headline)
            .foregroundColor(isSelected ? .black : .black.opacity(0.45))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.6) : Color.clear)
            )
            .onTapGesture {
                onTap()
            }
    }
}
