//
//  CustomWeightsView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/22/26.
//

import Foundation
import SwiftUI
import Supabase

struct CustomWeightsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    let userId: UUID?
    private let originalWeights: ScoreWeights
    @State private var isSaving: Bool = false
    @State private var draftWeights: ScoreWeights
    @State private var draftSelectedMonth: Int
    @State private var hasSaved: Bool = false

    init(userId: UUID?, initialWeights: ScoreWeights, initialSelectedMonth: Int) {
        self.userId = userId
        self.originalWeights = initialWeights
        _draftWeights = State(initialValue: initialWeights)
        _draftSelectedMonth = State(initialValue: initialSelectedMonth)
    }
    
    // MARK: - Derived State
    
    private var totalWeight: Double {
        draftWeights.advisory +
        draftWeights.visa +
        draftWeights.affordability +
        draftWeights.seasonality
    }
    
    private var isZeroSum: Bool {
        totalWeight <= 0.0001
    }
    
    private var isDirty: Bool {
        originalWeights.advisory != draftWeights.advisory ||
        originalWeights.visa != draftWeights.visa ||
        originalWeights.affordability != draftWeights.affordability ||
        originalWeights.seasonality != draftWeights.seasonality ||
        weightsStore.selectedMonth != draftSelectedMonth
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("travel1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Color.black.opacity(0.12)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        topBanner

                        sectionCard(title: "Quick Presets") {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                presetButton(title: "Balanced", preset: .balanced)
                                presetButton(title: "Budget", preset: .budget)
                                presetButton(title: "Easy Travel", preset: .easyTravel)
                                presetButton(title: "Safety First", preset: .safetyFirst)
                            }
                        }

                        sectionCard(title: "Weights") {
                            VStack(spacing: 18) {
                                if isZeroSum {
                                    Text("At least one category must have weight.")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                }

                                weightSlider(
                                    title: "Affordability",
                                    value: binding(for: \.affordability)
                                )

                                weightSlider(
                                    title: "Visa Ease",
                                    value: binding(for: \.visa)
                                )

                                weightSlider(
                                    title: "Travel Advisory",
                                    value: binding(for: \.advisory)
                                )

                                seasonalityWeightControl

                            }
                        }

                        sectionCard(title: "Actions") {
                            VStack(spacing: 12) {
                                Button {
                                    Task {
                                        await saveWeights()
                                    }
                                } label: {
                                    Text(hasSaved ? "Saved" : "Save Preferences")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(isDirty ? Theme.accent : Color.gray.opacity(0.28))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .disabled(isSaving || isZeroSum || !isDirty)

                                Button {
                                    let defaults = ScoreWeights.default
                                    draftWeights = defaults
                                    draftSelectedMonth = weightsStore.selectedMonth
                                } label: {
                                    Text("Reset to Default")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.black.opacity(0.06))
                                        .foregroundColor(Theme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                    .frame(width: geo.size.width - 40)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }

                VStack {
                    HStack {
                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            ZStack {
                                Theme.chromeIconButtonBackground(size: 40)
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
    }
    
    private func presetButton(title: String, preset: WeightPreset) -> some View {
        Button {
            draftWeights = preset.weights
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.96, green: 0.94, blue: 0.88).opacity(0.96))
                )
                .foregroundColor(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.borderless)
    }
    
    // MARK: - Slider
    
    private func weightSlider(title: String, value: Binding<Double>) -> some View {
        let percentage: Double = totalWeight > 0
            ? (value.wrappedValue / totalWeight) * 100
            : 0

        return VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.black)
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.55))
            }

            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { newValue in
                        let clamped = min(max(newValue, 0), 1)
                        value.wrappedValue = clamped
                    }
                ),
                in: 0...1,
                step: 0.05
            )
            .tint(Color(red: 0.76, green: 0.48, blue: 0.31))
        }
        .padding(.vertical, 6)
    }

    private var seasonalityWeightControl: some View {
        let value = binding(for: \.seasonality)
        let percentage: Double = totalWeight > 0
            ? (value.wrappedValue / totalWeight) * 100
            : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Seasonality")
                    .font(.headline)
                    .foregroundStyle(.black)

                Spacer()

                Text(String(format: "%.0f%%", percentage))
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.55))
            }

            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: { newValue in
                        let clamped = min(max(newValue, 0), 1)
                        value.wrappedValue = clamped
                    }
                ),
                in: 0...1,
                step: 0.05
            )
            .tint(Color(red: 0.76, green: 0.48, blue: 0.31))

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allMonthsMeta) { month in
                            Button {
                                draftSelectedMonth = month.id
                            } label: {
                                Text(month.short)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .fill(draftSelectedMonth == month.id ? Color.white.opacity(0.78) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .id(month.id)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(draftSelectedMonth, anchor: .center)
                }
                .onChange(of: draftSelectedMonth) { _, month in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(month, anchor: .center)
                    }
                }
            }

            Text("Uses your selected travel month. Changing it here also updates When To Go.")
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.52))
        }
        .padding(.vertical, 6)
    }

    private var topBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Travel Preferences")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black)

            Text("Your selected weights determine how Travelability Scores are calculated throughout the app. Rankings update after you save.")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(cardSurface(corner: 28))
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.black)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardSurface(corner: 24))
    }

    private func cardSurface(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color(red: 0.95, green: 0.93, blue: 0.88).opacity(0.97))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
    }
    
    // MARK: - Save
    
    private func saveWeights() async {
        isSaving = true
        defer { isSaving = false }

        weightsStore.updatePreferences(
            weights: draftWeights,
            selectedMonth: draftSelectedMonth
        )
        hasSaved = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hasSaved = false
        }

        guard let userId else { return }

        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString)
        else {
            print("❌ Missing Supabase config")
            return
        }

        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )

        do {
            struct PreferencesRow: Encodable {
                let user_id: UUID
                let advisory: Double
                let seasonality: Double
                let visa: Double
                let affordability: Double
            }

            let row = PreferencesRow(
                user_id: userId,
                advisory: draftWeights.advisory,
                seasonality: draftWeights.seasonality,
                visa: draftWeights.visa,
                affordability: draftWeights.affordability
            )

            try await client
                .from("user_score_preferences")
                .upsert(row)
                .execute()
        } catch {
            print("❌ Failed saving weights:", error)
        }
    }

    private func binding(for keyPath: WritableKeyPath<ScoreWeights, Double>) -> Binding<Double> {
        Binding(
            get: { draftWeights[keyPath: keyPath] },
            set: { draftWeights[keyPath: keyPath] = min(max($0, 0), 1) }
        )
    }
}
