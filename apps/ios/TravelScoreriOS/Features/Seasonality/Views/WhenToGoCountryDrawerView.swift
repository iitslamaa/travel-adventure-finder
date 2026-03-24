//
//  WhenToGoCountryDrawerView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/20/26.
//

import SwiftUI

struct WhenToGoCountryDrawerView: View {
    @EnvironmentObject private var weightsStore: ScoreWeightsStore

    let country: WhenToGoItem
    @State private var showCountryDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

            // MARK: - Header Card
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(country.country.localizedDisplayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .layoutPriority(1)

                            Text(country.country.flagEmoji)
                                .font(.system(size: 26))
                                .fixedSize()
                        }

                        if let region = country.country.localizedRegionLabel {
                            Text(region.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 4) {
                        if let overall = country.country.score {
                            ScorePill(score: overall)
                        } else {
                            Text("common.em_dash")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(.gray.opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(.gray.opacity(0.3), lineWidth: 1)
                                )
                        }

                        Text("seasonality.drawer.overall")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(20)
            .background(
                Theme.countryDetailCardBackground(corner: 24)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // MARK: - Seasonality Insight
            VStack(alignment: .leading, spacing: 16) {
                let selectedMonthName = CountrySeasonalityHelpers.fullMonthName(for: weightsStore.selectedMonth)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: String(localized: "country_detail.seasonality.title_format"), locale: AppDisplayLocale.current, selectedMonthName))
                            .font(.headline)

                        Text("seasonality.drawer.monthly_conditions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let seasonalityScore = country.country.resolvedSeasonalityScore(for: weightsStore.selectedMonth) {
                        Text(AppNumberFormatting.integerString(seasonalityScore))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(CountryScoreStyling.backgroundColor(for: seasonalityScore))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(CountryScoreStyling.borderColor(for: seasonalityScore), lineWidth: 1)
                            )
                    } else {
                        Text("common.em_dash")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.gray.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(CountrySeasonalityHelpers.headline(for: country.country, selectedMonth: weightsStore.selectedMonth))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(CountrySeasonalityHelpers.body(for: country.country, selectedMonth: weightsStore.selectedMonth))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let months = country.country.seasonalityBestMonths,
                   !months.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("country_detail.seasonality.best_months")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                            ForEach(months, id: \.self) { month in
                                Text(CountrySeasonalityHelpers.shortMonthName(for: month))
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.12))
                                    )
                            }
                        }
                    }
                }

            }
            .padding(20)
            .background(
                Theme.countryDetailCardBackground(corner: 24)
            )
            .padding(.horizontal, 20)


            }
        }
        .background(
            ZStack {
                Image("travel5")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .opacity(0.20)
                    .ignoresSafeArea()
            }
        )
        .safeAreaInset(edge: .bottom) {
            Button {
                showCountryDetail = true
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Text("seasonality.drawer.view_full_country_details")
                        .font(.headline.weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(Color(red: 0.20, green: 0.14, blue: 0.10))
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(red: 0.95, green: 0.91, blue: 0.83).opacity(0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.65), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.0),
                        Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .sheet(isPresented: $showCountryDetail) {
            NavigationStack {
                CountryDetailView(country: country.country)
            }
            .presentationBackground(.clear)
            .preferredColorScheme(.light)
        }
        .scrollIndicators(.hidden)
        .preferredColorScheme(.light)
    }

    private func scoreRow(title: String, value: Double, weightPercentage: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.seasonality.weight_format"), locale: AppDisplayLocale.current, weightPercentage)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ScorePill(score: value)
        }
        .padding(.vertical, 6)
    }
}
