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
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset
    
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
        VStack(spacing: 8) {
            monthScroller
            content
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
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
    
    private var monthScroller: some View {
        ZStack {
            Image("title_background")
                .resizable()
                .scaledToFill()

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(allMonthsMeta) { month in
                            MonthChip(
                                month: month,
                                isSelected: viewModel.selectedMonthIndex == month.id
                            ) {
                                viewModel.selectedMonthIndex = month.id
                            }
                            .id(month.id)
                        }
                    }
                    .padding(.horizontal, 56)
                }
                .padding(.horizontal, 18)
                .onAppear {
                    centerMonth(viewModel.selectedMonthIndex, using: proxy, animated: false)
                }
                .onChange(of: viewModel.selectedMonthIndex) { _, month in
                    centerMonth(month, using: proxy, animated: true)
                }
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
                .padding(.bottom, floatingTabBarInset + 8)
            }
        }
        .scrollIndicators(.hidden)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.95, green: 0.92, blue: 0.87).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
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
                .foregroundStyle(.black)
            
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

    private func centerMonth(_ month: Int, using proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(month, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                action()
            }
        } else {
            action()
        }
    }
}

private struct MonthChip: View {
    let month: MonthMeta
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(month.short)
            .font(.headline)
            .foregroundColor(.black)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.55) : Color.clear)
            )
            .onTapGesture {
                onTap()
            }
    }
}
