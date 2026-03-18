//
//  CollapsibleCountrySection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/13/26.
//

import Foundation
import SwiftUI

struct CollapsibleCountrySection: View {
    let title: String
    let countryCodes: [String]
    let highlightColor: Color
    let mutualCountries: Set<String>?

    @State private var isExpanded = false
    @State private var selectedCountryISO: String? = nil
    @State private var hasLoadedMap = false
    @State private var isLoadingMap: Bool = false

    init(
        title: String,
        countryCodes: [String],
        highlightColor: Color,
        mutualCountries: Set<String>? = nil
    ) {
        self.title = title
        self.countryCodes = countryCodes
        self.highlightColor = highlightColor
        self.mutualCountries = mutualCountries
    }

    var body: some View {
        let normalizedMutuals = Set(
            mutualCountries?.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            } ?? []
        )
        let orderedFlags = countryCodes.filter { code in
            normalizedMutuals.contains(
                code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            )
        }
        +
        countryCodes.filter { code in
            !normalizedMutuals.contains(
                code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            )
        }

        VStack(alignment: .leading, spacing: 12) {

            Button {
                if !isExpanded && !hasLoadedMap {
                    hasLoadedMap = true
                }
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
                    Text("\(title): ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(countryCodes.count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(highlightColor)
                    Spacer()
                }
            }

            if hasLoadedMap {
                VStack(spacing: 16) {

                    // 🔎 Normalize ISO codes once (ISO2 contract)
                    let normalizedISOs = countryCodes
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            FlagStrip(
                                flags: orderedFlags,
                                fontSize: 30,
                                spacing: 10,
                                showsTooltip: false,
                                selectedISO: selectedCountryISO,
                                onFlagTap: {
                                    let normalized = $0
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .uppercased()
                                    selectedCountryISO = normalized
                                },
                                mutualCountries: mutualCountries
                            )
                        }
                        .onAppear {
                            scrollToSelectedCountry(with: proxy, animated: false)
                        }
                        .onChange(of: isExpanded) { _, expanded in
                            guard expanded else { return }
                            DispatchQueue.main.async {
                                scrollToSelectedCountry(with: proxy, animated: false)
                            }
                        }
                        .onChange(of: selectedCountryISO) {
                            scrollToSelectedCountry(with: proxy, animated: true)
                        }
                    }

                    ZStack(alignment: .bottom) {

                        ScoreWorldMapRepresentable(
                            countries: [],
                            highlightedISOs: normalizedISOs,
                            selectedCountryISO: $selectedCountryISO,
                            isLoading: $isLoadingMap
                        )
                        .id(title + normalizedISOs.joined())
                        .onAppear {
                        }
                        .onDisappear {
                        }
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .preferredColorScheme(nil)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        if let iso = selectedCountryISO {
                            HStack(spacing: 8) {
                                Text(flagEmoji(from: iso))
                                Text(Locale.current.localizedString(forRegionCode: iso) ?? iso)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .fill(Color.white.opacity(0.24))
                                    )
                            )
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                        }
                    }
                }
                .padding(.top, 8)
                .opacity(isExpanded ? 1 : 0)
                .frame(height: isExpanded ? nil : 0)
                .clipped()
            }
        }
        .padding(16)
        .background(Theme.profileCardBackground(corner: 20))
        .onAppear {
        }
        .onDisappear {
        }
        .onChange(of: countryCodes) {
            isExpanded = false
            hasLoadedMap = false
            let normalizedCodes = orderedFlags.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
            if let selectedCountryISO,
               !normalizedCodes.contains(selectedCountryISO) {
                self.selectedCountryISO = nil
            }
        }
    }

    private func scrollToSelectedCountry(
        with proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard let selectedCountryISO else { return }

        let scrollAction = {
            proxy.scrollTo(selectedCountryISO, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }

    private func flagEmoji(from code: String) -> String {
        code.uppercased().unicodeScalars
            .map { 127397 + $0.value }
            .compactMap(UnicodeScalar.init)
            .map(String.init)
            .joined()
    }
}

struct FlagStrip: View {
    let flags: [String]
    let fontSize: CGFloat
    let spacing: CGFloat
    let showsTooltip: Bool
    let selectedISO: String?
    let onFlagTap: ((String) -> Void)?
    let mutualCountries: Set<String>?

    init(
        flags: [String],
        fontSize: CGFloat,
        spacing: CGFloat,
        showsTooltip: Bool = false,
        selectedISO: String? = nil,
        onFlagTap: ((String) -> Void)? = nil,
        mutualCountries: Set<String>? = nil
    ) {
        self.flags = flags
        self.fontSize = fontSize
        self.spacing = spacing
        self.showsTooltip = showsTooltip
        self.selectedISO = selectedISO
        self.onFlagTap = onFlagTap
        self.mutualCountries = mutualCountries
    }

    var body: some View {
        LazyHStack(spacing: spacing) {
            ForEach(Array(flags), id: \.self) { (code: String) in
                let normalizedCode = code
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()

                let flag = flagEmoji(from: normalizedCode)

                let normalizedMutuals = mutualCountries?.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .uppercased()
                }

                let isMutual = normalizedMutuals?.contains(normalizedCode) ?? false
                let isSelected = selectedISO?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased() == normalizedCode


                Text(flag)
                    .font(.system(size: fontSize))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                isMutual
                                ? Color.gold.opacity(0.35)
                                : (isSelected ? Color.blue.opacity(0.25) : Color.clear)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.blue :
                                (isMutual ? Color.gold : Color.clear),
                                lineWidth: 2
                            )
                    )
                    .contentShape(Rectangle())
                    .id(normalizedCode)
                    .onTapGesture {
                        onFlagTap?(normalizedCode)
                    }
            }
        }
    }

    private func flagEmoji(from code: String) -> String {
        code.uppercased().unicodeScalars
            .map { 127397 + $0.value }
            .compactMap(UnicodeScalar.init)
            .map(String.init)
            .joined()
    }
}
