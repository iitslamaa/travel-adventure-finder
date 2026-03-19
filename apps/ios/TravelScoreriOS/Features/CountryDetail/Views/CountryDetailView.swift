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
    @StateObject private var engagementVM = CountryFriendEngagementViewModel()
    @State private var activeSheet: CountryDetailSheet?

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
                                    weightPercentage: weightsStore.visaPercentage
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

            async let profileReload: Void = sessionManager.isAuthenticated ? profileVM.reloadProfile() : ()
            async let countryRefresh: Void = refreshCountryIfAvailable()
            async let languageProfileRefresh: CountryLanguageProfile? = try? await CountryLanguageProfileStore.shared.refreshProfile(for: country.iso2)
            async let engagementRefresh: Void = engagementVM.load(
                countryCode: country.iso2,
                currentUserId: sessionManager.userId,
                isAuthenticated: sessionManager.isAuthenticated
            )

            _ = await profileReload
            _ = await countryRefresh
            country = await visaStore.hydrate(country: country)
            countryLanguageProfile = await languageProfileRefresh
            _ = await engagementRefresh
            isPreparingContent = false
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .engagement:
                CountryFriendEngagementSheet(
                    country: displayedCountry,
                    engagement: engagementVM.engagement
                )
            case .profile(let userId):
                CountryFriendProfileSheet(userId: userId)
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

private enum CountryDetailSheet: Identifiable {
    case engagement
    case profile(UUID)

    var id: String {
        switch self {
        case .engagement:
            return "engagement"
        case .profile(let userId):
            return "profile-\(userId.uuidString)"
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
                    Text("Your friends")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if isLoading {
                        Text("Checking who knows \(country.name)")
                            .font(TAFTypography.body(.semibold))
                            .foregroundStyle(.primary)

                        Text("Loading travel signals from your circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(primaryCopy)
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

    private var primaryCopy: String {
        if !engagement.visited.isEmpty {
            return "See who's been to \(country.name)"
        }
        if !engagement.fromHere.isEmpty {
            return "See who's from \(country.name)"
        }
        if !engagement.bucketList.isEmpty {
            return "See who wants to go to \(country.name)"
        }
        if engagement.totalFriends == 0 {
            return "See what your friends know about \(country.name)"
        }
        return "See which friends know \(country.name)"
    }

    private var secondaryCopy: String {
        if engagement.totalFriends == 0 {
            return "Add friends to unlock travel signals here."
        }

        let parts = [
            summaryPart(count: engagement.visited.count, singular: "visited"),
            summaryPart(count: engagement.bucketList.count, singular: "want to go"),
            summaryPart(count: engagement.fromHere.count, singular: "from here")
        ]
        .compactMap { $0 }

        if parts.isEmpty {
            return "\(engagement.totalFriends) friends, no travel signals yet"
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friends who know \(country.name)")
                        .font(TAFTypography.section(.semibold))

                    Text("See who has visited, wants to go, or is from here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if engagement.totalFriends > 0 {
                    Text("\(engagement.totalFriends) friends")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.08))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                engagementGroup(
                    title: "Visited",
                    symbol: "checkmark.circle.fill",
                    tint: .green,
                    profiles: engagement.visited
                )
                engagementGroup(
                    title: "Bucket list",
                    symbol: "bookmark.fill",
                    tint: Color(red: 0.84, green: 0.51, blue: 0.18),
                    profiles: engagement.bucketList
                )
                engagementGroup(
                    title: "From here",
                    symbol: "house.fill",
                    tint: Color(red: 0.24, green: 0.44, blue: 0.72),
                    profiles: engagement.fromHere
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

                Text("\(profiles.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if profiles.isEmpty {
                Text("Nobody yet")
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
                                    .fill(Color.white.opacity(0.52))
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

    @StateObject private var socialNav = SocialNavigationController()

    var body: some View {
        NavigationStack(path: $socialNav.path) {
            ProfileView(userId: userId, showsBackButton: true)
                .environmentObject(socialNav)
                .navigationDestination(for: SocialRoute.self) { route in
                    socialDestination(route)
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

private struct CountryFriendEngagementSheet: View {
    let country: Country
    let engagement: CountryFriendEngagement

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfile: SelectedFriendProfile?

    var body: some View {
        NavigationStack {
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
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(
                Theme.pageBackground("travel3", tint: 0.10)
                    .ignoresSafeArea()
            )
            .navigationTitle(country.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedProfile) { selectedProfile in
                CountryFriendProfileSheet(userId: selectedProfile.id)
            }
        }
        .presentationDetents([.medium, .large])
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
        guard let evidence else { return "Why this score?" }

        if let title = evidence.title, title.localizedCaseInsensitiveContains("glottolog") {
            return "Source: Glottolog"
        }

        if let title = evidence.title, title.localizedCaseInsensitiveContains("britannica") {
            return "Source: Britannica"
        }

        if let host = evidence.url?.host(percentEncoded: false)?
            .replacingOccurrences(of: "www.", with: ""),
           !host.isEmpty {
            return "Why this score?"
        }

        return "Why this score?"
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
                headline: "A normal language score does not really apply here.",
                detail: "This territory has no permanent settled population, so there is no typical resident language environment to score against.",
                primaryLanguageCode: "",
                evidence: evidence
            )
        }

        let normalizedUserLanguages = userLanguages.map { language in
            ScoredUserLanguage(
                code: LanguageRepository.shared.canonicalLanguageCode(for: language.code)
                    ?? language.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                proficiency: LanguageProficiency(storageValue: language.proficiency)
            )
        }

        let userLanguageByCode = Dictionary(
            uniqueKeysWithValues: normalizedUserLanguages.map { ($0.code, $0) }
        )

        let exactMatches = countryProfile.languages.compactMap { countryLanguage -> ExactLanguageMatch? in
            let normalizedCode = countryLanguage.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard let userLanguage = userLanguageByCode[normalizedCode] else {
                return nil
            }

            return ExactLanguageMatch(
                code: normalizedCode,
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
                headline: "Language may be a barrier here.",
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
        let languageName = LanguageRepository.shared.displayName(for: match.code)

        switch score {
        case 100:
            return "You'll be comfortable traveling here in \(languageName)."
        case 50:
            if match.proficiency == .conversational {
                return "You can likely get by here in \(languageName)."
            }
            return "\(languageName) should help in many travel situations here."
        default:
            if match.proficiency == .beginner {
                return "You can practice your \(languageName) here, but you may not want to rely on it."
            }
            return "Language may still be a barrier in parts of the country."
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
            let practiceLanguage = LanguageRepository.shared.displayName(for: practice.code)
            return "You can also practice your \(practiceLanguage) here."
        }

        if strongestMatch.proficiency == .conversational && strongestMatch.coverage < 0.65 {
            return "Expect things to feel easiest in major tourist areas."
        }

        if strongestMatch.proficiency == .fluent && strongestMatch.coverage < 0.65 {
            return "It should be most useful in tourism-heavy areas rather than everywhere."
        }

        return nil
    }

    private struct ScoredUserLanguage {
        let code: String
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
                Text("Language Compatibility")
                    .font(.headline)

                Spacer()

                Text("Your languages · \(weightPercentage)%")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("\(result.score)")
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

            Text("Based on country-level language coverage and your saved language codes. Real-world experience can vary by city and region.")
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
