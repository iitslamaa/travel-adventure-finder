//
//  CollapsibleCountrySection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/13/26.
//

import Foundation
import SwiftUI

struct CollapsibleCountrySection: View {
    let sectionID: String
    let title: String
    let countryCodes: [String]
    let highlightColor: Color
    let mutualCountries: Set<String>?
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var selectedCountryISO: String? = nil
    @State private var isLoadingMap: Bool = false

    init(
        sectionID: String,
        title: String,
        countryCodes: [String],
        highlightColor: Color,
        mutualCountries: Set<String>? = nil,
        isExpanded: Bool = false,
        onToggle: @escaping () -> Void = {}
    ) {
        self.sectionID = sectionID
        self.title = title
        self.countryCodes = countryCodes
        self.highlightColor = highlightColor
        self.mutualCountries = mutualCountries
        self.isExpanded = isExpanded
        self.onToggle = onToggle
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
                onToggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
                    Text("\(title): ")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(AppNumberFormatting.integerString(countryCodes.count))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(highlightColor)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if isExpanded {
                VStack(spacing: 16) {

                    // Normalize ISO codes once for the map/flag strip contract.
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
                        .id(sectionID + normalizedISOs.joined())
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
                                    .font(.headline)
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
            }
        }
        .padding(16)
        .background(cardBackground(corner: 20))
        .background(
            Theme.profileCardBackground(corner: 18)
                .padding(.horizontal, -10)
                .padding(.vertical, -8)
        )
        .onAppear {
        }
        .onDisappear {
        }
        .onChange(of: countryCodes) {
            let normalizedCodes = orderedFlags.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
            if let selectedCountryISO,
               !normalizedCodes.contains(selectedCountryISO) {
                self.selectedCountryISO = nil
            }
        }
    }

    private func cardBackground(corner: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack {
                Image("profile_header")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(1.35, anchor: .trailing)
                    .offset(x: 36)
                    .clipped()

                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(0.18))
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
            .allowsHitTesting(false)
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
