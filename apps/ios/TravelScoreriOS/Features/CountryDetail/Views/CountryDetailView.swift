//
//  CountryDetailView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import SwiftUI
import PostgREST
import Supabase
import Combine
import MapKit
import CryptoKit

#if canImport(Translation)
import Translation
#endif

struct CountryDetailView: View {
    @State var country: Country
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var bucketListStore: BucketListStore
    @EnvironmentObject private var traveledStore: TraveledStore
    @StateObject private var visaStore = VisaRequirementsStore.shared
    @State private var scrollAnchor: String? = nil
    @State private var countryLanguageProfile: CountryLanguageProfile?
    @State private var isPreparingContent: Bool = true
    @State private var isResolvingVisaContext: Bool = false
    @StateObject private var engagementVM = CountryFriendEngagementViewModel()
    @State private var activeSheet: CountryDetailSheet?

    private var passportFallbackCountryCode: String {
        profileVM.effectivePassportCountryCode?.nilIfBlank ?? "US"
    }

    private var shouldPromptForPassportSetup: Bool {
        sessionManager.isAuthenticated && profileVM.passportNationalities.isEmpty
    }

    private var displayedCountry: Country {
        country.applyingOverallScore(using: weightsStore.weights, selectedMonth: weightsStore.selectedMonth)
    }

    private var languageCompatibility: CountryLanguageCompatibilityResult? {
        guard
            let profile = profileVM.profile,
            let countryLanguageProfile
        else {
            return nil
        }

        return CountryLanguageCompatibilityScorer.evaluate(
            userLanguages: profile.languages,
            countryProfile: countryLanguageProfile
        )
    }

    private var isBucketed: Bool {
        bucketListStore.ids.contains(country.id)
    }

    private var isVisited: Bool {
        traveledStore.ids.contains(country.id)
    }

    private var localizedVisaPassportLabels: [String] {
        let currentPassportCodes = profileVM.passportNationalities
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }

        if let passportCode = country.visaPassportCode?.nilIfBlank,
           currentPassportCodes.isEmpty || currentPassportCodes.contains(passportCode.uppercased()) {
            return [CountrySelectionFormatter.localizedName(for: passportCode)]
        }

        if
            let rawLabel = country.visaPassportLabel?.nilIfBlank,
            rawLabel.contains(" / ")
        {
            if !currentPassportCodes.isEmpty {
                return currentPassportCodes.map(CountrySelectionFormatter.localizedName(for:))
            }

            return rawLabel
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let rawLabel = country.visaPassportLabel?.nilIfBlank,
           currentPassportCodes.isEmpty {
            return [rawLabel]
        }

        if let effectivePassportCode = profileVM.effectivePassportCountryCode?.nilIfBlank {
            return [CountrySelectionFormatter.localizedName(for: effectivePassportCode)]
        }

        if shouldPromptForPassportSetup {
            return [CountrySelectionFormatter.localizedName(for: passportFallbackCountryCode)]
        }

        if let activePassportLabel = visaStore.activePassportLabel?.nilIfBlank {
            return [activePassportLabel]
        }

        return []
    }

    private var visaPassportLabel: String {
        if !localizedVisaPassportLabels.isEmpty {
            return localizedVisaPassportLabels.joined(separator: " / ")
        }

        if profileVM.passportNationalities.count > 1 {
            return String(localized: "trip_planner.visa.best_saved_passport")
        }

        return visaStore.activePassportLabel ?? String(localized: "trip_planner.visa.default_passport_label")
    }

    private var recommendedPassportLabel: String? {
        guard profileVM.passportNationalities.count > 1 else { return nil }

        if let passportCode = country.visaPassportCode?.nilIfBlank {
            return CountrySelectionFormatter.localizedName(for: passportCode)
        }

        return country.visaRecommendedPassportLabel?.nilIfBlank
    }

    private var equalBestPassportLabels: [String] {
        guard profileVM.passportNationalities.count > 1 else { return [] }
        guard recommendedPassportLabel == nil else { return [] }
        return localizedVisaPassportLabels.count > 1 ? localizedVisaPassportLabels : []
    }

    private var shouldShowPassportRecommendation: Bool {
        guard profileVM.passportNationalities.count > 1 else { return false }
        return recommendedPassportLabel != nil || equalBestPassportLabels.count > 1
    }

    private var shouldResolveVisaContextBeforeDisplay: Bool {
        guard sessionManager.isAuthenticated else { return false }
        guard profileVM.userId == sessionManager.userId else { return false }
        return !profileVM.hasLoadedCoreData
    }

    @MainActor
    private func refreshCountryIfAvailable() async {
        let iso2 = country.iso2.uppercased()

        if let cached = CountryAPI.loadCachedCountries()?.first(where: { $0.iso2.uppercased() == iso2 }) {
            country = cached
        }

        if let refreshed = await CountryAPI.refreshCountriesIfNeeded(minInterval: 0)?
            .first(where: { $0.iso2.uppercased() == iso2 }) {
            country = refreshed
            return
        }

        if let fetched = try? await CountryAPI.fetchCountries()
            .first(where: { $0.iso2.uppercased() == iso2 }) {
            country = fetched
        }
    }

    @MainActor
    private func refreshVisaPresentation() async {
        country = await visaStore.hydrate(
            country: country,
            passportCountryCodes: profileVM.passportNationalities,
            fallbackPassportCountryCode: passportFallbackCountryCode
        )
    }
    
    var body: some View {
        Group {
            if isPreparingContent {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.1)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 28) {

                                // Header polaroid style
                                CountryHeaderCard(country: displayedCountry)
                                    .padding()
                                    .background(
                                        Theme.countryDetailCardBackground(corner: 20)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 12, y: 8)

                                scrapbookSection {
                                    CountryOverviewCard(country: displayedCountry)
                                }

                                if sessionManager.isAuthenticated {
                                    scrapbookSection {
                                        CountryFriendEngagementPreviewCard(
                                            country: displayedCountry,
                                            engagement: engagementVM.engagement,
                                            isLoading: engagementVM.isLoading,
                                            onOpen: {
                                                activeSheet = .engagement
                                            }
                                        )
                                    }
                                }

                                // Advisory card stack
                                scrapbookSection {
                                    CountryAdvisoryCard(
                                        country: displayedCountry,
                                        weightPercentage: weightsStore.advisoryPercentage
                                    )
                                }

                                // Seasonality card stack
                                scrapbookSection {
                                    CountrySeasonalityCard(
                                        country: displayedCountry,
                                        weightPercentage: weightsStore.seasonalityPercentage
                                    )
                                }

                                // Visa card stack
                                scrapbookSection {
                                    CountryVisaCard(
                                        country: displayedCountry,
                                        weightPercentage: weightsStore.visaPercentage,
                                        isLoading: isResolvingVisaContext,
                                        passportLabel: visaPassportLabel,
                                        recommendedPassportLabel: recommendedPassportLabel,
                                        equalBestPassportLabels: equalBestPassportLabels,
                                        showPassportRecommendation: shouldShowPassportRecommendation,
                                        showsPassportSetupPrompt: shouldPromptForPassportSetup,
                                        onOpenPassportSettings: {
                                            guard let userId = sessionManager.userId else { return }
                                            activeSheet = .passportSettings(userId)
                                        }
                                    )
                                }

                                // Affordability card stack
                                if displayedCountry.affordabilityScore != nil {
                                    scrapbookSection {
                                        CountryAffordabilityCard(
                                            country: displayedCountry,
                                            weightPercentage: weightsStore.affordabilityPercentage
                                        )
                                    }
                                }

                                if let languageCompatibility {
                                    scrapbookSection {
                                        CountryLanguageCompatibilityCard(
                                            result: languageCompatibility,
                                            weightPercentage: weightsStore.languagePercentage
                                        )
                                    }
                                }
                            }
                            .id("countryDetailTop")
                            .padding(.top, 24)
                            .padding(.horizontal)
                            .safeAreaPadding(.bottom)
                            .frame(width: geometry.size.width, alignment: .top)
                        }
                    }
                }
            }
        }
        .background(
            ZStack {
                Image("travel5")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .opacity(0.22)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.08),
                        Color.black.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.light)
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                PlanningListActionButton(kind: .bucket, isActive: isBucketed) {
                    Task {
                        await toggleBucket()
                    }
                }

                PlanningListActionButton(kind: .visited, isActive: isVisited) {
                    Task {
                        await toggleVisited()
                    }
                }
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .task(id: country.iso2.uppercased()) {
            isPreparingContent = true
            let shouldResolveVisaContext = shouldResolveVisaContextBeforeDisplay
            isResolvingVisaContext = shouldResolveVisaContext

            Task {
                await engagementVM.load(
                    countryCode: country.iso2,
                    currentUserId: sessionManager.userId,
                    isAuthenticated: sessionManager.isAuthenticated
                )
            }

            async let profileLoad: Void = {
                guard shouldResolveVisaContext else { return }
                await profileVM.loadIfNeeded()
            }()
            async let countryRefresh: Void = refreshCountryIfAvailable()
            async let languageProfileRefresh: CountryLanguageProfile? = try? await CountryLanguageProfileStore.shared.refreshProfile(for: country.iso2)

            _ = await countryRefresh
            _ = await profileLoad
            await refreshVisaPresentation()
            isResolvingVisaContext = false
            countryLanguageProfile = await languageProfileRefresh
            isPreparingContent = false
        }
        .onChange(of: profileVM.passportPreferences) { _, _ in
            Task {
                await refreshVisaPresentation()
            }
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            switch sheet {
            case .engagement:
                CountryFriendEngagementSheet(
                    country: displayedCountry,
                    engagement: engagementVM.engagement
                )
            case .profile(let userId):
                CountryFriendProfileSheet(userId: userId)
            case .passportSettings(let userId):
                CountryPassportSettingsSheet(userId: userId, profileVM: profileVM)
            }
        }
    }
    
    private func scrapbookSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(
                Theme.countryDetailCardBackground(corner: 20)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }

    @MainActor
    private func toggleBucket() async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedBucketListCountries != bucketListStore.ids {
                profileVM.viewedBucketListCountries = bucketListStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleBucket(country.id)
            bucketListStore.replace(with: profileVM.viewedBucketListCountries)
        } else {
            bucketListStore.toggle(country.id)
        }
    }

    @MainActor
    private func toggleVisited() async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedTraveledCountries != traveledStore.ids {
                profileVM.viewedTraveledCountries = traveledStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleTraveled(country.id)
            traveledStore.replace(with: profileVM.viewedTraveledCountries)
        } else {
            traveledStore.toggle(country.id)
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum CountryDetailSheet: Identifiable {
    case engagement
    case profile(UUID)
    case passportSettings(UUID)

    var id: String {
        switch self {
        case .engagement:
            return "engagement"
        case .profile(let userId):
            return "profile-\(userId.uuidString)"
        case .passportSettings(let userId):
            return "passport-settings-\(userId.uuidString)"
        }
    }
}

private struct SelectedFriendProfile: Identifiable {
    let id: UUID
}

private struct CountryFriendEngagement {
    let totalFriends: Int
    let visited: [Profile]
    let bucketList: [Profile]
    let fromHere: [Profile]

    static let empty = CountryFriendEngagement(
        totalFriends: 0,
        visited: [],
        bucketList: [],
        fromHere: []
    )

    var hasMatches: Bool {
        !visited.isEmpty || !bucketList.isEmpty || !fromHere.isEmpty
    }
}

@MainActor
private final class CountryFriendEngagementViewModel: ObservableObject {
    @Published private(set) var engagement: CountryFriendEngagement = .empty
    @Published private(set) var isLoading = false

    private let service = CountryFriendEngagementService()

    func load(countryCode: String, currentUserId: UUID?, isAuthenticated: Bool) async {
        guard isAuthenticated, let currentUserId else {
            engagement = .empty
            isLoading = false
            return
        }

        isLoading = true

        do {
            engagement = try await service.fetchEngagement(
                for: countryCode,
                currentUserId: currentUserId
            )
        } catch {
            print("❌ failed to load country friend engagement:", error)
            engagement = .empty
        }

        isLoading = false
    }
}

private struct EngagementUserRow: Decodable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

private struct CountryFriendEngagementService {
    private let supabase = SupabaseManager.shared
    private let friendService = FriendService(supabase: .shared)

    func fetchEngagement(
        for countryCode: String,
        currentUserId: UUID
    ) async throws -> CountryFriendEngagement {
        let normalizedCountryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let friends = try await friendService.fetchFriends(for: currentUserId)

        guard !friends.isEmpty else {
            return .empty
        }

        let friendIds = friends.map(\.id)
        let profilesById = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })

        async let visitedIds = fetchFriendIDs(
            in: "user_traveled",
            countryCode: normalizedCountryCode,
            friendIds: friendIds
        )
        async let bucketIds = fetchFriendIDs(
            in: "user_bucket_list",
            countryCode: normalizedCountryCode,
            friendIds: friendIds
        )

        let fromHere = friends
            .filter { profile in
                profile.livedCountries.contains { livedCountry in
                    livedCountry.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == normalizedCountryCode
                }
            }
            .sorted(by: profileSort)

        return CountryFriendEngagement(
            totalFriends: friends.count,
            visited: profiles(for: try await visitedIds, from: profilesById),
            bucketList: profiles(for: try await bucketIds, from: profilesById),
            fromHere: fromHere
        )
    }

    private func fetchFriendIDs(
        in table: String,
        countryCode: String,
        friendIds: [UUID]
    ) async throws -> Set<UUID> {
        let response: PostgrestResponse<[EngagementUserRow]> = try await supabase.client
            .from(table)
            .select("user_id")
            .eq("country_id", value: countryCode)
            .in("user_id", values: friendIds.map(\.uuidString))
            .limit(1000)
            .execute()

        return Set(response.value.map(\.userId))
    }

    private func profiles(
        for ids: Set<UUID>,
        from profilesById: [UUID: Profile]
    ) -> [Profile] {
        ids.compactMap { profilesById[$0] }
            .sorted(by: profileSort)
    }

    private func profileSort(lhs: Profile, rhs: Profile) -> Bool {
        let lhsName = lhs.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhsName = rhs.fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        if lhsName.isEmpty || rhsName.isEmpty {
            return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
        }

        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
    }
}

private struct CountryFriendEngagementPreviewCard: View {
    let country: Country
    let engagement: CountryFriendEngagement
    let isLoading: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                friendPreviewStack

                VStack(alignment: .leading, spacing: 4) {
                    Text("country_detail.friends.preview_title")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if isLoading {
                        Text(country.localizedDisplayName)
                            .font(TAFTypography.body(.semibold))
                            .foregroundStyle(.primary)

                        Text("country_detail.friends.loading_signals")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(country.localizedDisplayName)
                            .font(TAFTypography.body(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(secondaryCopy)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var secondaryCopy: String {
        if engagement.totalFriends == 0 {
            return String(localized: "country_detail.friends.unlock_signals")
        }

        let parts = [
            summaryPart(count: engagement.visited.count, singular: String(localized: "country_detail.friends.visited")),
            summaryPart(count: engagement.bucketList.count, singular: String(localized: "country_detail.friends.want_to_go")),
            summaryPart(count: engagement.fromHere.count, singular: String(localized: "country_detail.friends.from_here"))
        ]
        .compactMap { $0 }

        if parts.isEmpty {
            return String(format: String(localized: "country_detail.friends.no_signals_format"), locale: AppDisplayLocale.current, engagement.totalFriends)
        }

        return parts.joined(separator: " • ")
    }

    private func summaryPart(count: Int, singular: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(singular)"
    }

    private var friendPreviewStack: some View {
        ZStack(alignment: .leading) {
            if previewProfiles.isEmpty {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.secondary)
                    }
            } else {
                ForEach(Array(previewProfiles.enumerated()), id: \.element.id) { index, profile in
                    FriendAvatarView(profile: profile)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        )
                        .offset(x: CGFloat(index) * 22)
                        .zIndex(Double(previewProfiles.count - index))
                }
            }
        }
        .frame(width: previewStackWidth, height: 48, alignment: .leading)
    }

    private var previewProfiles: [Profile] {
        var seen = Set<UUID>()
        let combined = engagement.visited + engagement.fromHere + engagement.bucketList

        return combined.filter { profile in
            seen.insert(profile.id).inserted
        }
        .prefix(3)
        .map { $0 }
    }

    private var previewStackWidth: CGFloat {
        previewProfiles.isEmpty ? 48 : CGFloat(42 + max(previewProfiles.count - 1, 0) * 22)
    }
}

private struct CountryFriendEngagementCard: View {
    let country: Country
    let engagement: CountryFriendEngagement
    let onSelectProfile: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Theme.scrapbookBack(corner: 24)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("country_detail.friends.see_who")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    if engagement.totalFriends > 0 {
                        Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.friends.friend_count_format"), locale: AppDisplayLocale.current, engagement.totalFriends)))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.88, green: 0.84, blue: 0.77).opacity(0.78))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    engagementGroup(
                        title: String(localized: "country_detail.friends.visited"),
                        symbol: "checkmark.circle.fill",
                        tint: Color(red: 0.38, green: 0.56, blue: 0.34),
                        profiles: engagement.visited
                    )
                    engagementGroup(
                        title: String(localized: "country_detail.friends.bucket_list"),
                        symbol: "bookmark.fill",
                        tint: Color(red: 0.72, green: 0.46, blue: 0.20),
                        profiles: engagement.bucketList
                    )
                    engagementGroup(
                        title: String(localized: "country_detail.friends.from_here"),
                        symbol: "house.fill",
                        tint: Color(red: 0.46, green: 0.47, blue: 0.60),
                        profiles: engagement.fromHere
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.91, blue: 0.84).opacity(0.68))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.26), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            HStack {
                Theme.tape(width: 68, height: 18)
                Spacer()
                Theme.tape(width: 54, height: 16)
            }
            .padding(.horizontal, 42)
            .offset(y: -9)
        }
    }

    @ViewBuilder
    private func engagementGroup(
        title: String,
        symbol: String,
        tint: Color,
        profiles: [Profile]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer()

                Text(AppNumberFormatting.integerString(profiles.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if profiles.isEmpty {
                Text("country_detail.friends.nobody_yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(profiles, id: \.id) { profile in
                        Button {
                            onSelectProfile(profile.id)
                        } label: {
                            HStack(spacing: 12) {
                                FriendAvatarView(profile: profile)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.fullName.isEmpty ? profile.username : profile.fullName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("@\(profile.username)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 0.98, green: 0.95, blue: 0.90).opacity(0.74))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct FriendAvatarView: View {
    let profile: Profile

    var body: some View {
        Group {
            if let avatarURL = profile.avatarUrl,
               !avatarURL.isEmpty,
               let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.08))

            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(4)
        }
    }
}

private struct CountryFriendProfileSheet: View {
    let userId: UUID

    @Environment(\.dismiss) private var dismiss
    @StateObject private var socialNav = SocialNavigationController()

    var body: some View {
        NavigationStack(path: $socialNav.path) {
            ProfileView(userId: userId, showsBackButton: true)
                .environmentObject(socialNav)
                .navigationDestination(for: SocialRoute.self) { route in
                    socialDestination(route)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func socialDestination(_ route: SocialRoute) -> some View {
        switch route {
        case .profile(let routeUserId):
            ProfileView(userId: routeUserId, showsBackButton: true)
                .environmentObject(socialNav)
        case .friends(let routeUserId):
            FriendsView(userId: routeUserId, showsBackButton: true)
                .environmentObject(socialNav)
        case .friendRequests:
            FriendRequestsView()
                .environmentObject(socialNav)
        }
    }
}

private struct CountryPassportSettingsSheet: View {
    let userId: UUID
    @ObservedObject var profileVM: ProfileViewModel

    var body: some View {
        NavigationStack {
            ProfileSettingsView(
                profileVM: profileVM,
                viewedUserId: userId
            )
        }
    }
}

private struct CountryFriendEngagementSheet: View {
    let country: Country
    let engagement: CountryFriendEngagement

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfile: SelectedFriendProfile?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.pageBackground("travel3", tint: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        Theme.titleBanner("\(country.localizedDisplayName) \(country.flagEmoji)")

                        Button {
                            dismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 40, height: 40)

                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                        .padding(.trailing, 18)
                    }

                    ScrollView {
                        VStack(spacing: 18) {
                            CountryFriendEngagementCard(
                                country: country,
                                engagement: engagement,
                                onSelectProfile: { userId in
                                    selectedProfile = SelectedFriendProfile(id: userId)
                                }
                            )
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedProfile) { selectedProfile in
                CountryFriendProfileSheet(userId: selectedProfile.id)
            }
        }
    }
}

private struct CountryLanguageProfile: Decodable {
    let countryISO2: String
    let source: String?
    let sourceVersion: String?
    let notes: String?
    let evidence: [CountryLanguageEvidence]
    let languages: [CountryLanguageCoverage]

    enum CodingKeys: String, CodingKey {
        case countryISO2 = "country_iso2"
        case source
        case sourceVersion = "source_version"
        case notes
        case evidence
        case languages
    }
}

private struct CountryLanguageCoverage: Decodable, Hashable {
    let code: String
    let type: String
    let coverage: Double
}

private struct CountryLanguageEvidence: Decodable, Hashable {
    let kind: String?
    let title: String?
    let url: URL?
    let note: String?
}

private struct CountryLanguageCompatibilityResult {
    let score: Int
    let headline: String
    let detail: String?
    let primaryLanguageCode: String
    let evidence: CountryLanguageEvidence?

    var evidenceLinkLabel: String {
        guard let evidence else { return String(localized: "country_detail.language.why_score") }

        if let title = evidence.title, title.localizedCaseInsensitiveContains("glottolog") {
            return String(localized: "country_detail.language.source_glottolog")
        }

        if let title = evidence.title, title.localizedCaseInsensitiveContains("britannica") {
            return String(localized: "country_detail.language.source_britannica")
        }

        if let host = evidence.url?.host(percentEncoded: false)?
            .replacingOccurrences(of: "www.", with: ""),
           !host.isEmpty {
            return String(localized: "country_detail.language.why_score")
        }

        return String(localized: "country_detail.language.why_score")
    }
}

private actor CountryLanguageProfileStore {
    static let shared = CountryLanguageProfileStore()

    private var cache: [String: CountryLanguageProfile] = [:]
    private var missingISO2: Set<String> = []

    func profile(for iso2: String) async throws -> CountryLanguageProfile? {
        let normalizedISO2 = iso2.uppercased()

        if let cached = cache[normalizedISO2] {
            return cached
        }

        if missingISO2.contains(normalizedISO2) {
            return nil
        }

        let response: PostgrestResponse<[CountryLanguageProfile]> = try await SupabaseManager.shared.client
            .from("country_language_profiles")
            .select("country_iso2,source,source_version,notes,evidence,languages")
            .eq("country_iso2", value: normalizedISO2)
            .limit(1)
            .execute()

        guard let profile = response.value.first else {
            missingISO2.insert(normalizedISO2)
            return nil
        }

        cache[normalizedISO2] = profile
        return profile
    }

    func refreshProfile(for iso2: String) async throws -> CountryLanguageProfile? {
        let normalizedISO2 = iso2.uppercased()

        let response: PostgrestResponse<[CountryLanguageProfile]> = try await SupabaseManager.shared.client
            .from("country_language_profiles")
            .select("country_iso2,source,source_version,notes,evidence,languages")
            .eq("country_iso2", value: normalizedISO2)
            .limit(1)
            .execute()

        guard let profile = response.value.first else {
            cache.removeValue(forKey: normalizedISO2)
            missingISO2.insert(normalizedISO2)
            return nil
        }

        missingISO2.remove(normalizedISO2)
        cache[normalizedISO2] = profile
        return profile
    }
}

private enum CountryLanguageCompatibilityScorer {
    static func evaluate(
        userLanguages: [Profile.LanguageJSON],
        countryProfile: CountryLanguageProfile
    ) -> CountryLanguageCompatibilityResult? {
        let evidence = countryProfile.evidence.first(where: { $0.url != nil && $0.kind?.lowercased() != "inference" })
            ?? countryProfile.evidence.first(where: { $0.url != nil })

        if countryProfile.languages.isEmpty {
            return CountryLanguageCompatibilityResult(
                score: 0,
                headline: String(localized: "country_detail.language.empty.headline"),
                detail: String(localized: "country_detail.language.empty.detail"),
                primaryLanguageCode: "",
                evidence: evidence
            )
        }

        let normalizedUserLanguages = userLanguages.map { language in
            ScoredUserLanguage(
                codes: LanguageRepository.shared.compatibilityLanguageCodes(for: language.code),
                proficiency: LanguageProficiency(storageValue: language.proficiency)
            )
        }

        let exactMatches = countryProfile.languages.compactMap { countryLanguage -> ExactLanguageMatch? in
            let normalizedCodes = LanguageRepository.shared.compatibilityLanguageCodes(for: countryLanguage.code)

            guard let userLanguage = normalizedUserLanguages.first(where: { !$0.codes.isDisjoint(with: normalizedCodes) }) else {
                return nil
            }

            return ExactLanguageMatch(
                code: countryLanguage.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                type: countryLanguage.type,
                coverage: countryLanguage.coverage,
                proficiency: userLanguage.proficiency,
                compatibility: userLanguage.proficiency.compatibilityMultiplier * countryLanguage.coverage
            )
        }

        guard let strongestMatch = exactMatches.max(by: { lhs, rhs in
            if lhs.compatibility != rhs.compatibility {
                return lhs.compatibility < rhs.compatibility
            }

            if lhs.proficiency.normalizedScore != rhs.proficiency.normalizedScore {
                return lhs.proficiency.normalizedScore < rhs.proficiency.normalizedScore
            }

            return lhs.coverage < rhs.coverage
        }) else {
            return CountryLanguageCompatibilityResult(
                score: 0,
                headline: String(localized: "country_detail.language.barrier"),
                detail: nil,
                primaryLanguageCode: "",
                evidence: evidence
            )
        }

        let score = normalizedScore(for: strongestMatch.compatibility)
        let headline = headline(for: strongestMatch, score: score)
        let detail = detailText(for: strongestMatch, allMatches: exactMatches)

        return CountryLanguageCompatibilityResult(
            score: score,
            headline: headline,
            detail: detail,
            primaryLanguageCode: strongestMatch.code,
            evidence: evidence
        )
    }

    private static func normalizedScore(for compatibility: Double) -> Int {
        switch compatibility {
        case 0.65...:
            return 100
        case 0.30...:
            return 50
        default:
            return 0
        }
    }

    private static func headline(for match: ExactLanguageMatch, score: Int) -> String {
        let languageName = LanguageRepository.shared.localizedDisplayName(for: match.code)

        switch score {
        case 100:
            return String(format: String(localized: "country_detail.language.headline.comfortable"), languageName)
        case 50:
            if match.proficiency == .conversational {
                return String(format: String(localized: "country_detail.language.headline.get_by"), languageName)
            }
            return String(format: String(localized: "country_detail.language.headline.helpful"), languageName)
        default:
            if match.proficiency == .beginner {
                return String(format: String(localized: "country_detail.language.headline.practice"), languageName)
            }
            return String(localized: "country_detail.language.headline.barrier_parts")
        }
    }

    private static func detailText(
        for strongestMatch: ExactLanguageMatch,
        allMatches: [ExactLanguageMatch]
    ) -> String? {
        let practiceMatches = allMatches
            .filter { $0.code != strongestMatch.code && $0.proficiency == .beginner && $0.coverage >= 0.6 }
            .sorted { $0.coverage > $1.coverage }

        if let practice = practiceMatches.first {
            let practiceLanguage = LanguageRepository.shared.localizedDisplayName(for: practice.code)
            return String(format: String(localized: "country_detail.language.detail.practice_also"), practiceLanguage)
        }

        if strongestMatch.proficiency == .conversational && strongestMatch.coverage < 0.65 {
            return String(localized: "country_detail.language.detail.tourist_areas")
        }

        if strongestMatch.proficiency == .fluent && strongestMatch.coverage < 0.65 {
            return String(localized: "country_detail.language.detail.tourism_heavy")
        }

        return nil
    }

    private struct ScoredUserLanguage {
        let codes: Set<String>
        let proficiency: LanguageProficiency
    }

    private struct ExactLanguageMatch {
        let code: String
        let type: String
        let coverage: Double
        let proficiency: LanguageProficiency
        let compatibility: Double
    }
}

private struct CountryLanguageCompatibilityCard: View {
    let result: CountryLanguageCompatibilityResult
    let weightPercentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("country_detail.language.title")
                    .font(.headline)

                Spacer()

                Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.language.your_languages_weight_format"), locale: AppDisplayLocale.current, weightPercentage)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(AppNumberFormatting.integerString(result.score))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(CountryScoreStyling.backgroundColor(for: result.score))
                    )
                    .overlay(
                        Capsule()
                            .stroke(CountryScoreStyling.borderColor(for: result.score), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = result.detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let evidenceURL = result.evidence?.url {
                Link(result.evidenceLinkLabel, destination: evidenceURL)
                    .font(.footnote.weight(.semibold))
            }

            Text("country_detail.language.footer")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CountryOverviewCard: View {
    let country: Country
    @StateObject private var viewModel = CountryOverviewDescriptionViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.displayedDescription)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            CountryStaticMapView(country: country)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: country.iso2.uppercased()) {
            viewModel.load(country: country)
        }
        #if canImport(Translation)
        .modifier(CountryOverviewTranslationModifier(country: country, viewModel: viewModel))
        #endif
    }
}

#if canImport(Translation)
private struct CountryOverviewTranslationModifier: ViewModifier {
    let country: Country
    @ObservedObject var viewModel: CountryOverviewDescriptionViewModel

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let target = viewModel.translationTargetLanguage {
            content.translationTask(
                source: Locale.Language(identifier: "en"),
                target: target
            ) { session in
                await viewModel.translateIfNeeded(country: country, session: session)
            }
        } else {
            content
        }
    }
}
#endif

@MainActor
private final class CountryOverviewDescriptionViewModel: ObservableObject {
    @Published private(set) var displayedDescription = ""

    private let cache = CountryOverviewTranslationCache.shared
    private var lastTranslationKey: String?

    var translationTargetLanguage: Locale.Language? {
        let language = Locale.autoupdatingCurrent.language
        guard language.languageCode?.identifier.lowercased() != "en" else { return nil }
        return language
    }

    func load(country: Country) {
        let localeIdentifier = Locale.autoupdatingCurrent.identifier

        if let bundled = CountryOverviewDescriptionStore.bundledLocalizedDescription(
            for: country,
            localeIdentifier: localeIdentifier
        ) {
            displayedDescription = bundled
            lastTranslationKey = nil
            return
        }

        guard let canonical = CountryOverviewDescriptionStore.canonicalDescription(for: country) else {
            displayedDescription = CountryOverviewDescriptionStore.description(for: country)
            lastTranslationKey = nil
            return
        }

        displayedDescription = canonical
        let cacheKey = Self.cacheKey(
            iso: country.iso2,
            localeIdentifier: localeIdentifier,
            source: canonical
        )
        lastTranslationKey = cacheKey

        Task {
            if let cached = await cache.translation(for: cacheKey) {
                await MainActor.run {
                    guard self.lastTranslationKey == cacheKey else { return }
                    self.displayedDescription = cached
                }
            }
        }
    }

    #if canImport(Translation)
    @available(iOS 18.0, *)
    func translateIfNeeded(country: Country, session: TranslationSession) async {
        let localeIdentifier = Locale.autoupdatingCurrent.identifier

        if CountryOverviewDescriptionStore.bundledLocalizedDescription(
            for: country,
            localeIdentifier: localeIdentifier
        ) != nil {
            return
        }

        guard
            let canonical = CountryOverviewDescriptionStore.canonicalDescription(for: country),
            let cacheKey = lastTranslationKey
        else {
            return
        }

        if let cached = await cache.translation(for: cacheKey) {
            guard lastTranslationKey == cacheKey else { return }
            displayedDescription = cached
            return
        }

        do {
            try await session.prepareTranslation()
            let response = try await session.translate(canonical)
            let translated = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translated.isEmpty else { return }

            await cache.store(translated, for: cacheKey)
            guard lastTranslationKey == cacheKey else { return }
            displayedDescription = translated
        } catch {
            return
        }
    }
    #endif

    private static func cacheKey(iso: String, localeIdentifier: String, source: String) -> String {
        let digest = SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(iso.uppercased())|\(localeIdentifier.lowercased())|\(digest)"
    }
}

private actor CountryOverviewTranslationCache {
    static let shared = CountryOverviewTranslationCache()

    private struct CacheFile: Codable {
        var entries: [String: String]
    }

    private let fileURL: URL
    private var entries: [String: String]

    init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("CountryOverviewTranslations", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        fileURL = directoryURL.appendingPathComponent("cache.json")

        if
            let data = try? Data(contentsOf: fileURL),
            let file = try? JSONDecoder().decode(CacheFile.self, from: data)
        {
            entries = file.entries
        } else {
            entries = [:]
        }
    }

    func translation(for key: String) -> String? {
        entries[key]
    }

    func store(_ translation: String, for key: String) {
        entries[key] = translation
        let file = CacheFile(entries: entries)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}

private struct CountryStaticMapView: UIViewRepresentable {
    let country: Country

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.preferredConfiguration = config
        mapView.mapType = .mutedStandard
        mapView.showsBuildings = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isUserInteractionEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let iso = country.iso2.uppercased()

        if context.coordinator.currentISO != iso {
            context.coordinator.currentISO = iso
            let overlays = CountryMapRegionResolver.overlays(for: iso)
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(overlays)
        }

        if let override = CountryMapRegionResolver.regionOverride(for: iso) {
            mapView.setRegion(override, animated: false)
            return
        }

        let overlays = mapView.overlays
        guard let firstOverlay = overlays.first else { return }

        let combinedRect = overlays.dropFirst().reduce(firstOverlay.boundingMapRect) { partial, overlay in
            partial.union(overlay.boundingMapRect)
        }

        mapView.setVisibleMapRect(
            combinedRect,
            edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
            animated: false
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentISO: String?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? CountryPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKMultiPolygonRenderer(overlay: polygon)
            renderer.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.32)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 0.92)
            renderer.lineWidth = 1.6
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}

private enum CountryMapRegionResolver {
    static func overlays(for iso: String) -> [CountryPolygon] {
        // The full-resolution dataset produces a broken partial fill for a few small countries
        // in the static detail card map (notably Albania). The simplified geometry is more stable
        // for this non-interactive preview while still preserving the country silhouette well.
        WorldGeoJSONLoader.loadPolygons()
            .filter { $0.isoCode?.uppercased() == iso }
    }

    static func regionOverride(for iso: String) -> MKCoordinateRegion? {
        switch iso {
        case "BQ":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.18, longitude: -68.25),
                span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
            )
        case "AS":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -14.27, longitude: -170.70),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
            )
        case "CN":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.0, longitude: 103.0),
                span: MKCoordinateSpan(latitudeDelta: 28.0, longitudeDelta: 28.0)
            )
        case "DZ":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 28.0, longitude: 2.6),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "FJ":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -17.8, longitude: 178.0),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "FR":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.5),
                span: MKCoordinateSpan(latitudeDelta: 11.0, longitudeDelta: 11.0)
            )
        case "GB":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 54.5, longitude: -3.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "KI":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 1.9, longitude: -157.4),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 30.0)
            )
        case "NZ":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -41.0, longitude: 173.0),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 12.0)
            )
        case "RU":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.0, longitude: 100.0),
                span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 100.0)
            )
        case "SB":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -9.6, longitude: 160.2),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "SG":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 1.35, longitude: 103.82),
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            )
        case "SH":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -15.96, longitude: -5.72),
                span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
            )
        case "SL":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 8.6, longitude: -11.8),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "SR":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 4.0, longitude: -56.0),
                span: MKCoordinateSpan(latitudeDelta: 7.0, longitudeDelta: 7.0)
            )
        case "TF":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -49.3, longitude: 69.2),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "US":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 70.0)
            )
        default:
            return nil
        }
    }
}
