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
    
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var isSaving: Bool = false
    @State private var originalWeights: ScoreWeights? = nil
    @State private var hasSaved: Bool = false
    
    // MARK: - Derived State
    
    private var totalWeight: Double {
        weightsStore.weights.advisory +
        weightsStore.weights.visa +
        weightsStore.weights.affordability
    }
    
    private var isZeroSum: Bool {
        totalWeight <= 0.0001
    }
    
    private var isDirty: Bool {
        guard let original = originalWeights else { return false }
        return original.advisory != weightsStore.weights.advisory ||
               original.visa != weightsStore.weights.visa ||
               original.affordability != weightsStore.weights.affordability
    }
    
    var body: some View {
        Form {
            
            Section("Quick Presets") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        presetButton(
                            title: "Balanced",
                            preset: .balanced
                        )

                        presetButton(
                            title: "Budget",
                            preset: .budget
                        )
                    }

                    HStack(spacing: 12) {
                        presetButton(
                            title: "Easy Travel",
                            preset: .easyTravel
                        )

                        presetButton(
                            title: "Safety First",
                            preset: .safetyFirst
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                
                if isZeroSum {
                    Text("At least one category must have weight.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                
                weightSlider(
                    title: "Affordability",
                    value: $weightsStore.weights.affordability
                )

                weightSlider(
                    title: "Visa Ease",
                    value: $weightsStore.weights.visa
                )

                weightSlider(
                    title: "Travel Advisory",
                    value: $weightsStore.weights.advisory
                )
                
                Text("Your selected weights determine how Travelability Scores are calculated throughout the app. All country rankings, comparisons, and visualizations will reflect these preferences once saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            
            Section {
                Button {
                    Task {
                        await saveWeightsToBackend()
                    }
                } label: {
                    Text(hasSaved ? "Saved ✓" : "Save Preferences")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isDirty ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(sessionManager.userId == nil || isSaving || isZeroSum || !isDirty)
                .animation(.easeInOut, value: isDirty)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        weightsStore.resetToDefault()
                    }
                } label: {
                    Text("Reset to Default")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
        .onAppear {
            if originalWeights == nil {
                originalWeights = weightsStore.weights
            }
        }
        .navigationTitle("Travel Preferences")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func presetButton(title: String, preset: WeightPreset) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                weightsStore.applyPreset(preset)
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(10)
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
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .foregroundStyle(.secondary)
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
            .animation(.easeInOut, value: value.wrappedValue)
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Save
    
    private func saveWeightsToBackend() async {
        guard let userId = sessionManager.userId else { return }

        isSaving = true
        defer { isSaving = false }

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
                let visa: Double
                let affordability: Double
            }

            let row = PreferencesRow(
                user_id: userId,
                advisory: weightsStore.weights.advisory,
                visa: weightsStore.weights.visa,
                affordability: weightsStore.weights.affordability
            )

            try await client
                .from("user_score_preferences")
                .upsert(row)
                .execute()

            
            originalWeights = weightsStore.weights
            hasSaved = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasSaved = false
            }
        } catch {
            print("❌ Failed saving weights:", error)
        }
    }
}
