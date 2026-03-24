//
//  PlanningView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/5/26.
//

import SwiftUI
import Combine
import EventKit
import EventKitUI
import NukeUI
import Supabase
import PostgREST

enum PlanningListKind {
    case bucket
    case visited

    var title: String {
        switch self {
        case .bucket: return String(localized: "planning.bucket_list.title")
        case .visited: return String(localized: "planning.visited.title")
        }
    }

    var shortTitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.short")
        case .visited: return String(localized: "planning.list_kind.visited.short")
        }
    }

    var subtitle: String {
        switch self {
        case .bucket: return String(localized: "planning.bucket_list.subtitle")
        case .visited: return String(localized: "planning.visited.subtitle")
        }
    }

    var icon: String {
        switch self {
        case .bucket: return "bookmark"
        case .visited: return "checkmark.circle"
        }
    }

    var filledIcon: String {
        switch self {
        case .bucket: return "bookmark.fill"
        case .visited: return "checkmark.circle.fill"
        }
    }

    var otherListLabel: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.other_label")
        case .visited: return String(localized: "planning.list_kind.visited.other_label")
        }
    }

    var otherListName: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.visited.short")
        case .visited: return String(localized: "planning.list_kind.bucket.short")
        }
    }

    var pickerTitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.picker_title")
        case .visited: return String(localized: "planning.list_kind.visited.picker_title")
        }
    }

    var pickerSubtitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.picker_subtitle")
        case .visited: return String(localized: "planning.list_kind.visited.picker_subtitle")
        }
    }

    var navigationTitle: String {
        switch self {
        case .bucket: return "🪣 \(String(localized: "planning.bucket_list.title"))"
        case .visited: return "🎒 \(String(localized: "planning.visited.title"))"
        }
    }

    var emptyTitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.empty_title")
        case .visited: return String(localized: "planning.list_kind.visited.empty_title")
        }
    }

    var emptySystemImage: String {
        switch self {
        case .bucket: return "bookmark"
        case .visited: return "backpack"
        }
    }

    var emptyDescription: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.empty_description")
        case .visited: return String(localized: "planning.list_kind.visited.empty_description")
        }
    }

    var tint: Color {
        switch self {
        case .bucket: return .yellow
        case .visited: return .green
        }
    }
}

struct PlanningView: View {

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            ListsView()
                .background(.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lists Root

struct ListsView: View {
    @State private var scrollAnchor: String? = nil

    var body: some View {
        VStack(spacing: 0) {

            Theme.titleBanner(String(localized: "planning.title"))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {

                        NavigationLink {
                            BucketListView()
                        } label: {
                            PlanningCard(
                                title: String(localized: "planning.bucket_list.title"),
                                subtitle: String(localized: "planning.bucket_list.subtitle"),
                                icon: "bookmark"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MyTravelsView()
                        } label: {
                            PlanningCard(
                                title: String(localized: "planning.visited.title"),
                                subtitle: String(localized: "planning.visited.subtitle"),
                                icon: "checkmark.circle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlannerView()
                        } label: {
                            PlanningCard(
                                title: String(localized: "planning.trip_planner.title"),
                                subtitle: String(localized: "planning.trip_planner.subtitle"),
                                icon: "airplane.departure"
                            )
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 20)
                    }
                    .id("planningListTop")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .safeAreaPadding(.bottom)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Card

struct PlanningCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        Theme.featureCard(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            Image(systemName: "chevron.right")
                .foregroundColor(.black)
        }
    }
}

private struct TripPlannerNavigationChrome<Trailing: View>: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let showsBackButton: Bool
    let trailing: Trailing

    init(
        showsBackButton: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.showsBackButton = showsBackButton
        self.trailing = trailing()
    }

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                HStack {
                    if showsBackButton {
                        Button {
                            dismiss()
                        } label: {
                            ZStack {
                                Theme.chromeIconButtonBackground(size: 40)
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    trailing
                }
                .padding(.horizontal, Theme.pageHorizontalInset)
                .padding(.top, 12)
            }
    }
}

private extension View {
    func tripPlannerNavigationChrome<Trailing: View>(
        showsBackButton: Bool = true,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(
            TripPlannerNavigationChrome(
                showsBackButton: showsBackButton,
                trailing: trailing
            )
        )
    }
}

struct PlanningListActionButton: View {
    let kind: PlanningListKind
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isActive
                        ? kind.tint.opacity(0.90)
                        : Color.white.opacity(0.82)
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                isActive
                                ? kind.tint.opacity(0.95)
                                : Color.white.opacity(0.65),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                if kind == .bucket {
                    Text("🪣")
                        .font(.system(size: 22))
                        .opacity(isActive ? 1.0 : 0.85)
                } else {
                    Image(systemName: isActive ? kind.filledIcon : kind.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }

                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 17, height: 17)
                    .overlay(
                        Image(systemName: isActive ? "checkmark" : "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isActive ? Color.green : Color.black.opacity(0.72))
                    )
                    .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
                    .offset(x: 13, y: 13)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isActive
            ? String(format: String(localized: "planning.country_toggle.remove_format"), locale: Locale.current, kind.shortTitle)
            : String(format: String(localized: "planning.country_toggle.add_format"), locale: Locale.current, kind.shortTitle)
        )
    }
}

struct PlanningCountryPickerView: View {
    let kind: PlanningListKind
    let countries: [Country]
    let selectedIds: Set<String>
    let otherSelectedIds: Set<String>
    let onSave: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sort: CountrySort = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var draftSelectedIds: Set<String>
    @State private var isSaving = false

    init(
        kind: PlanningListKind,
        countries: [Country],
        selectedIds: Set<String>,
        otherSelectedIds: Set<String>,
        onSave: @escaping (Set<String>) -> Void
    ) {
        self.kind = kind
        self.countries = countries
        self.selectedIds = selectedIds
        self.otherSelectedIds = otherSelectedIds
        self.onSave = onSave
        _draftSelectedIds = State(initialValue: selectedIds)
    }

    private var hasChanges: Bool {
        draftSelectedIds != selectedIds
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Theme.chromeIconButtonBackground(size: 44)
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)

                DiscoveryControlsView(
                    sort: $sort,
                    sortOrder: $sortOrder
                )
                .frame(maxWidth: .infinity)

                Button {
                    isSaving = true
                    onSave(draftSelectedIds)
                    dismiss()
                } label: {
                    Text(isSaving ? String(localized: "common.saving") : String(localized: "common.save"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(hasChanges ? Theme.accent : Color.gray.opacity(0.55))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges || isSaving)
                .opacity(hasChanges ? 1 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            VStack(spacing: 4) {
                Text(kind.pickerTitle)
                    .font(.headline)
                    .foregroundStyle(.black)

                Text(kind.pickerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.black.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 4)

            CountryListView(
                showsSearchBar: true,
                searchText: $searchText,
                countries: countries,
                sort: $sort,
                sortOrder: $sortOrder,
                mode: .picker(
                    kind: kind,
                    selectedIds: draftSelectedIds,
                    otherSelectedIds: otherSelectedIds,
                    onSelect: { country in
                        if draftSelectedIds.contains(country.id) {
                            draftSelectedIds.remove(country.id)
                        } else {
                            draftSelectedIds.insert(country.id)
                        }
                    }
                )
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct TripPlannerFriendSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
}

enum TripPlannerAvailabilityKind: String, Codable, CaseIterable, Identifiable {
    case exactDates
    case flexibleMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exactDates:
            return String(localized: "trip_planner.availability.kind.exact_dates")
        case .flexibleMonth:
            return String(localized: "trip_planner.availability.kind.flexible_month")
        }
    }

    var subtitle: String {
        switch self {
        case .exactDates:
            return String(localized: "trip_planner.availability.kind.exact_dates_subtitle")
        case .flexibleMonth:
            return String(localized: "trip_planner.availability.kind.flexible_month_subtitle")
        }
    }
}

struct TripPlannerAvailabilityProposal: Codable, Identifiable, Hashable {
    let id: UUID
    let participantId: String
    let participantName: String
    let participantUsername: String?
    let participantAvatarURL: String?
    let kind: TripPlannerAvailabilityKind
    let startDate: Date
    let endDate: Date
}

enum TripPlannerDayPlanKind: String, Codable, CaseIterable, Identifiable {
    case country
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .country: return String(localized: "trip_planner.itinerary.country")
        case .travel: return String(localized: "trip_planner.itinerary.travel")
        }
    }
}

struct TripPlannerDayPlan: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let kind: TripPlannerDayPlanKind
    let countryId: String?
    let countryName: String?

    init(
        id: UUID = UUID(),
        date: Date,
        kind: TripPlannerDayPlanKind,
        countryId: String? = nil,
        countryName: String? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.kind = kind
        self.countryId = countryId
        self.countryName = countryName
    }
}

enum TripPlannerExpenseSplitMode: String, Codable, CaseIterable, Identifiable {
    case everyone
    case selectedPeople

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyone: return String(localized: "trip_planner.expenses.split_mode.everyone")
        case .selectedPeople: return String(localized: "trip_planner.expenses.split_mode.selected")
        }
    }
}

enum TripPlannerExpensePaymentMethod: String, Codable, CaseIterable, Identifiable {
    case manual
    case venmo
    case applePay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return String(localized: "trip_planner.expenses.manual")
        case .venmo: return String(localized: "trip_planner.expenses.venmo")
        case .applePay: return String(localized: "trip_planner.expenses.apple_pay")
        }
    }
}

struct TripPlannerExpenseShare: Codable, Identifiable, Hashable {
    let id: UUID
    let participantId: String
    let participantName: String
    let participantUsername: String?
    let amountOwed: Double
    let isPaid: Bool
    let paymentMethod: TripPlannerExpensePaymentMethod?

    init(
        id: UUID = UUID(),
        participantId: String,
        participantName: String,
        participantUsername: String?,
        amountOwed: Double,
        isPaid: Bool = false,
        paymentMethod: TripPlannerExpensePaymentMethod? = nil
    ) {
        self.id = id
        self.participantId = participantId
        self.participantName = participantName
        self.participantUsername = participantUsername
        self.amountOwed = amountOwed
        self.isPaid = isPaid
        self.paymentMethod = paymentMethod
    }
}

struct TripPlannerExpense: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let totalAmount: Double
    let paidById: String
    let paidByName: String
    let paidByUsername: String?
    let splitMode: TripPlannerExpenseSplitMode
    let date: Date
    let participantIds: [String]
    let participantNames: [String]
    let shares: [TripPlannerExpenseShare]

    init(
        id: UUID = UUID(),
        title: String,
        totalAmount: Double,
        paidById: String,
        paidByName: String,
        paidByUsername: String?,
        splitMode: TripPlannerExpenseSplitMode,
        date: Date = Date(),
        participantIds: [String],
        participantNames: [String],
        shares: [TripPlannerExpenseShare]
    ) {
        self.id = id
        self.title = title
        self.totalAmount = totalAmount
        self.paidById = paidById
        self.paidByName = paidByName
        self.paidByUsername = paidByUsername
        self.splitMode = splitMode
        self.date = date
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.shares = shares
    }
}

struct TripPlannerTrip: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let title: String
    let notes: String
    let startDate: Date?
    let endDate: Date?
    let countryIds: [String]
    let countryNames: [String]
    let friendIds: [UUID]
    let friendNames: [String]
    let friends: [TripPlannerFriendSnapshot]
    let availability: [TripPlannerAvailabilityProposal]
    let dayPlans: [TripPlannerDayPlan]
    let expenses: [TripPlannerExpense]

    var isGroupTrip: Bool {
        !friendIds.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case title
        case notes
        case startDate
        case endDate
        case countryIds
        case countryNames
        case friendIds
        case friendNames
        case friends
        case availability
        case dayPlans
        case expenses
    }

    init(
        id: UUID,
        createdAt: Date,
        title: String,
        notes: String,
        startDate: Date?,
        endDate: Date?,
        countryIds: [String],
        countryNames: [String],
        friendIds: [UUID],
        friendNames: [String],
        friends: [TripPlannerFriendSnapshot],
        availability: [TripPlannerAvailabilityProposal],
        dayPlans: [TripPlannerDayPlan] = [],
        expenses: [TripPlannerExpense] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.countryIds = countryIds
        self.countryNames = countryNames
        self.friendIds = friendIds
        self.friendNames = friendNames
        self.friends = friends
        self.availability = availability
        self.dayPlans = dayPlans
        self.expenses = expenses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        countryIds = try container.decode([String].self, forKey: .countryIds)
        countryNames = try container.decode([String].self, forKey: .countryNames)
        friendIds = try container.decodeIfPresent([UUID].self, forKey: .friendIds) ?? []
        friendNames = try container.decodeIfPresent([String].self, forKey: .friendNames) ?? []
        friends = try container.decodeIfPresent([TripPlannerFriendSnapshot].self, forKey: .friends)
            ?? zip(friendIds, friendNames).map { id, name in
                TripPlannerFriendSnapshot(
                    id: id,
                    displayName: name,
                    username: name.replacingOccurrences(of: " ", with: "").lowercased(),
                    avatarURL: nil
                )
            }
        availability = try container.decodeIfPresent([TripPlannerAvailabilityProposal].self, forKey: .availability) ?? []
        dayPlans = try container.decodeIfPresent([TripPlannerDayPlan].self, forKey: .dayPlans) ?? []
        expenses = try container.decodeIfPresent([TripPlannerExpense].self, forKey: .expenses) ?? []
    }
}

private enum TripPlannerDayPlanBuilder {
    static func syncedDayPlans(
        existingPlans: [TripPlannerDayPlan],
        startDate: Date?,
        endDate: Date?,
        countries: [(id: String, name: String)]
    ) -> [TripPlannerDayPlan] {
        guard let startDate, let endDate else { return [] }

        let calendar = Calendar.current
        let validCountryIDs = Set(countries.map(\.id))
        let namesByID = Dictionary(uniqueKeysWithValues: countries)
        let existingByDate = Dictionary(
            uniqueKeysWithValues: existingPlans.map { (calendar.startOfDay(for: $0.date), $0) }
        )

        return dateRange(from: startDate, to: endDate).map { date in
            if let existing = existingByDate[date] {
                if existing.kind == .travel {
                    return TripPlannerDayPlan(id: existing.id, date: date, kind: .travel)
                }

                if let countryId = existing.countryId, validCountryIDs.contains(countryId) {
                    return TripPlannerDayPlan(
                        id: existing.id,
                        date: date,
                        kind: .country,
                        countryId: countryId,
                        countryName: namesByID[countryId]
                    )
                }
            }

            if let firstCountry = countries.first {
                return TripPlannerDayPlan(
                    date: date,
                    kind: .country,
                    countryId: firstCountry.id,
                    countryName: Locale.autoupdatingCurrent.localizedString(forRegionCode: firstCountry.id.uppercased()) ?? firstCountry.name
                )
            }

            return TripPlannerDayPlan(date: date, kind: .travel)
        }
    }

    static func dateRange(from startDate: Date, to endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        var dates: [Date] = []
        var current = start

        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }
}

@MainActor
final class TripPlannerStore: ObservableObject {
    @Published private(set) var trips: [TripPlannerTrip] = []

    private let legacySaveKey = "trip_planner_trips_v1"
    private let guestSaveKey = "trip_planner_trips_guest_v1"
    private let supabase = SupabaseManager.shared
    private let syncService = TripPlannerSyncService(supabase: SupabaseManager.shared)
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadLocal()
        observeAuthState()

        Task {
            await refreshFromRemoteIfNeeded(migrateLocalTrips: true)
        }
    }

    func add(_ trip: TripPlannerTrip) {
        trips.insert(trip, at: 0)
        persistLocal()

        Task {
            await syncUpsert(trip)
        }
    }

    func upsert(_ trip: TripPlannerTrip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            trips.sort { $0.createdAt > $1.createdAt }
        } else {
            trips.insert(trip, at: 0)
        }
        persistLocal()

        Task {
            await syncUpsert(trip)
        }
    }

    func delete(id: UUID) {
        trips.removeAll { $0.id == id }
        persistLocal()

        Task {
            await syncDelete(id: id)
        }
    }

    private func observeAuthState() {
        supabase.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                Task {
                    await self.handleAuthStateChange()
                }
            }
            .store(in: &cancellables)
    }

    private func handleAuthStateChange() async {
        loadLocal()
        await refreshFromRemoteIfNeeded(migrateLocalTrips: true)
    }

    private var localSaveKey: String {
        guard let userId = supabase.currentUserId else {
            return guestSaveKey
        }

        return "trip_planner_trips_user_\(userId.uuidString)"
    }

    private func loadLocal() {
        let defaults = UserDefaults.standard
        let candidateKeys = [localSaveKey, legacySaveKey]

        for key in candidateKeys {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([TripPlannerTrip].self, from: data) else {
                continue
            }

            trips = decoded.sorted { $0.createdAt > $1.createdAt }
            return
        }

        trips = []
    }

    private func persistLocal() {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        UserDefaults.standard.set(data, forKey: localSaveKey)
    }

    private func refreshFromRemoteIfNeeded(migrateLocalTrips: Bool) async {
        guard let userId = supabase.currentUserId else { return }

        let localTrips = trips

        do {
            let remoteTrips = try await syncService.fetchTrips(userId: userId)
            let mergedTrips = mergedTrips(local: localTrips, remote: remoteTrips)

            if migrateLocalTrips {
                let localOnlyTrips = mergedTrips.filter { mergedTrip in
                    !remoteTrips.contains(where: { $0.id == mergedTrip.id })
                }

                for trip in localOnlyTrips {
                    try await syncService.upsertTrip(userId: userId, trip: trip)
                }
            }

            trips = mergedTrips
            persistLocal()

            if !mergedTrips.isEmpty {
                UserDefaults.standard.removeObject(forKey: legacySaveKey)
            }
        } catch {
            print("❌ Trip planner sync failed:", error)
        }
    }

    private func syncUpsert(_ trip: TripPlannerTrip) async {
        guard let userId = supabase.currentUserId else { return }

        do {
            try await syncService.upsertTrip(userId: userId, trip: trip)
            let remoteTrips = try await syncService.fetchTrips(userId: userId)
            trips = mergedTrips(local: trips, remote: remoteTrips)
            persistLocal()
        } catch {
            print("❌ Trip planner upsert failed:", error)
        }
    }

    private func syncDelete(id: UUID) async {
        guard let userId = supabase.currentUserId else { return }

        do {
            try await syncService.deleteTrip(userId: userId, tripId: id)
        } catch {
            print("❌ Trip planner delete failed:", error)
        }
    }

    private func mergedTrips(local: [TripPlannerTrip], remote: [TripPlannerTrip]) -> [TripPlannerTrip] {
        // Prefer the local copy when IDs collide so freshly edited trip data
        // does not get replaced by an older remote snapshot during refresh.
        var mergedByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for trip in remote where mergedByID[trip.id] == nil {
            mergedByID[trip.id] = trip
        }

        return mergedByID.values.sorted { $0.createdAt > $1.createdAt }
    }
}

private struct TripPlannerRemoteTripRow: Codable {
    let userId: UUID
    let tripId: UUID
    let tripData: TripPlannerTrip

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tripId = "trip_id"
        case tripData = "trip_data"
    }
}

private struct TripPlannerRemoteTripMutationRow: Codable {
    let userId: UUID
    let tripId: UUID
    let tripData: TripPlannerTrip

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tripId = "trip_id"
        case tripData = "trip_data"
    }
}

private struct TripPlannerSyncService {
    let supabase: SupabaseManager

    func fetchTrips(userId: UUID) async throws -> [TripPlannerTrip] {
        let rows: [TripPlannerRemoteTripRow] = try await supabase.client
            .from("user_trip_plans")
            .select("user_id,trip_id,trip_data")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows
            .map(\.tripData)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func upsertTrip(userId: UUID, trip: TripPlannerTrip) async throws {
        try await deleteTrip(userId: userId, tripId: trip.id)

        try await supabase.client
            .from("user_trip_plans")
            .insert(
                TripPlannerRemoteTripMutationRow(
                    userId: userId,
                    tripId: trip.id,
                    tripData: trip
                )
            )
            .execute()
    }

    func deleteTrip(userId: UUID, tripId: UUID) async throws {
        try await supabase.client
            .from("user_trip_plans")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("trip_id", value: tripId.uuidString)
            .execute()
    }
}

private struct TripPlannerCalendarDraft: Identifiable {
    let id = UUID()
    let store: EKEventStore
    let event: EKEvent
}

struct TripPlannerView: View {
    @StateObject private var store = TripPlannerStore()
    @State private var calendarDraft: TripPlannerCalendarDraft?
    @State private var calendarError: String?

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.title"))

                ScrollView {
                    VStack(spacing: 20) {
                        if store.trips.isEmpty {
                            NavigationLink {
                                TripPlannerComposerView { trip in
                                    store.add(trip)
                                }
                            } label: {
                                TripPlannerEmptyStateCard()
                            }
                            .buttonStyle(.plain)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(store.trips) { trip in
                                    NavigationLink {
                                        TripPlannerDetailView(
                                            trip: trip,
                                            onSave: { updatedTrip in
                                                store.upsert(updatedTrip)
                                            },
                                            onDelete: {
                                                store.delete(id: trip.id)
                                            },
                                            onAddToCalendar: { selectedTrip in
                                                Task {
                                                    await openCalendar(for: selectedTrip)
                                                }
                                            }
                                        )
                                    } label: {
                                        TripPlannerSavedTripCard(
                                            trip: trip,
                                            onDelete: {
                                                store.delete(id: trip.id)
                                            },
                                            onAddToCalendar: {
                                                Task {
                                                    await openCalendar(for: trip)
                                                }
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            NavigationLink {
                TripPlannerComposerView { trip in
                    store.add(trip)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))

                    Text("trip_planner.new_trip")
                        .font(.system(size: 15, weight: .bold))
                }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $calendarDraft) { draft in
            TripPlannerCalendarSheet(draft: draft)
        }
        .alert(String(localized: "trip_planner.calendar_access"), isPresented: Binding(
            get: { calendarError != nil },
            set: { newValue in
                if !newValue {
                    calendarError = nil
                }
            }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(calendarError ?? "")
        }
    }

    @MainActor
    private func openCalendar(for trip: TripPlannerTrip) async {
        guard let startDate = trip.startDate,
              let endDate = trip.endDate else {
            calendarError = String(localized: "trip_planner.calendar_error_missing_dates")
            return
        }

        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                calendarError = String(localized: "trip_planner.calendar_error_denied")
                return
            }

            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
            event.title = trip.title
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: startDate)
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate

            let noteParts = [
                trip.notes.isEmpty ? nil : trip.notes,
                trip.countryNames.isEmpty ? nil : String(
                    format: String(localized: "trip_planner.calendar_notes_countries"),
                    locale: Locale.current,
                    trip.countryNames.joined(separator: ", ")
                ),
                trip.friendNames.isEmpty ? nil : String(
                    format: String(localized: "trip_planner.calendar_notes_friends"),
                    locale: Locale.current,
                    trip.friendNames.joined(separator: ", ")
                )
            ].compactMap { $0 }
            event.notes = noteParts.joined(separator: "\n")

            calendarDraft = TripPlannerCalendarDraft(store: store, event: event)
        } catch {
            calendarError = error.localizedDescription.isEmpty
                ? String(localized: "trip_planner.calendar_error_generic")
                : error.localizedDescription
        }
    }
}

private struct TripPlannerComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var bucketListStore: BucketListStore

    let onSave: (TripPlannerTrip) -> Void
    var existingTrip: TripPlannerTrip? = nil

    @State private var countries: [Country] = []
    @State private var bucketCountryIds: Set<String> = []
    @State private var selectedCountryIds: Set<String> = []
    @State private var friends: [Profile] = []
    @State private var selectedFriendIds: Set<UUID> = []
    @State private var friendBucketLists: [UUID: Set<String>] = [:]

    @State private var title = ""
    @State private var notes = ""
    @State private var searchText = ""
    @State private var includeDates = true
    @State private var includeFriends = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    @State private var isLoading = true
    @State private var isLoadingShared = false
    @State private var calendarDraft: TripPlannerCalendarDraft?
    @State private var calendarError: String?
    @State private var friendsError: String?
    @State private var showingAllFriends = false
    @State private var showingBucketCountries = false

    private let friendService = FriendService()
    private let profileService = ProfileService(supabase: SupabaseManager.shared)

    init(
        existingTrip: TripPlannerTrip? = nil,
        onSave: @escaping (TripPlannerTrip) -> Void
    ) {
        self.onSave = onSave
        self.existingTrip = existingTrip
        _title = State(initialValue: existingTrip?.title ?? "")
        _notes = State(initialValue: existingTrip?.notes ?? "")
        _selectedCountryIds = State(initialValue: Set(existingTrip?.countryIds ?? []))
        _selectedFriendIds = State(initialValue: Set(existingTrip?.friendIds ?? []))
        _includeDates = State(initialValue: existingTrip?.startDate != nil || existingTrip?.endDate != nil)
        _includeFriends = State(initialValue: !(existingTrip?.friendIds.isEmpty ?? true))
        _startDate = State(initialValue: existingTrip?.startDate ?? Date())
        _endDate = State(initialValue: existingTrip?.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
    }

    private var rankedFriends: [Profile] {
        friends.sorted { lhs, rhs in
            let lhsSelected = selectedFriendIds.contains(lhs.id)
            let rhsSelected = selectedFriendIds.contains(rhs.id)
            if lhsSelected != rhsSelected {
                return lhsSelected && !rhsSelected
            }

            let lhsCount = mutualBucketCount(for: lhs.id)
            let rhsCount = mutualBucketCount(for: rhs.id)
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }

            return displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs)) == .orderedAscending
        }
    }

    private var selectedFriends: [Profile] {
        friends.filter { selectedFriendIds.contains($0.id) }
    }

    private var friendPreview: [Profile] {
        Array(rankedFriends.prefix(3))
    }

    private var sharedCountryIds: Set<String> {
        guard includeFriends, !selectedFriendIds.isEmpty else { return [] }

        var intersection = bucketCountryIds
        for friendId in selectedFriendIds {
            guard let friendBuckets = friendBucketLists[friendId] else { return [] }
            intersection.formIntersection(friendBuckets)
        }
        return intersection
    }

    private var sharedCountries: [Country] {
        countries
            .filter { sharedCountryIds.contains($0.id) && !selectedCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var countryBucketMatchCounts: [String: Int] {
        var counts: [String: Int] = [:]

        for countryId in bucketCountryIds {
            counts[countryId, default: 0] += 1
        }

        for friendId in selectedFriendIds {
            for countryId in friendBucketLists[friendId] ?? [] {
                counts[countryId, default: 0] += 1
            }
        }

        return counts
    }

    private var countryPickerSections: [TripPlannerCountryPickerSection] {
        let groupSize = selectedFriendIds.count + 1
        let unselectedCountries = countries.filter { !selectedCountryIds.contains($0.id) }
        var sections: [TripPlannerCountryPickerSection] = []

        if !selectedCountries.isEmpty {
            sections.append(
                TripPlannerCountryPickerSection(
                    title: String(localized: "trip_planner.country_picker.already_in_trip"),
                    countries: selectedCountries
                )
            )
        }

        if groupSize > 1 {
            let mutualCountries = unselectedCountries
                .filter { countryBucketMatchCounts[$0.id, default: 0] == groupSize }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if !mutualCountries.isEmpty {
                sections.append(
                    TripPlannerCountryPickerSection(
                        title: String(localized: "trip_planner.country_picker.everyones_bucket"),
                        countries: mutualCountries
                    )
                )
            }
        }

        if groupSize > 2 {
            for matchCount in stride(from: groupSize - 1, through: 2, by: -1) {
                let matchingCountries = unselectedCountries
                    .filter { countryBucketMatchCounts[$0.id, default: 0] == matchCount }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                if !matchingCountries.isEmpty {
                    sections.append(
                        TripPlannerCountryPickerSection(
                            title: String(
                                format: String(localized: "trip_planner.country_picker.match_count_format"),
                                locale: Locale.current,
                                matchCount,
                                groupSize
                            ),
                            countries: matchingCountries
                        )
                    )
                }
            }
        }

        let oneBucketCountries = unselectedCountries
            .filter { countryBucketMatchCounts[$0.id, default: 0] == 1 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !oneBucketCountries.isEmpty {
            sections.append(
                TripPlannerCountryPickerSection(
                    title: groupSize > 1 ? String(localized: "trip_planner.country_picker.one_person_bucket") : String(localized: "trip_planner.country_picker.from_your_bucket"),
                    countries: oneBucketCountries
                )
            )
        }

        let otherCountries = unselectedCountries
            .filter { countryBucketMatchCounts[$0.id, default: 0] == 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !otherCountries.isEmpty {
            sections.append(
                TripPlannerCountryPickerSection(
                    title: String(localized: "trip_planner.country_picker.all_other_countries"),
                    countries: otherCountries
                )
            )
        }

        return sections
    }

    private var selectedCountries: [Country] {
        countries
            .filter { selectedCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var canSave: Bool {
        !selectedCountryIds.isEmpty
            || !selectedFriendIds.isEmpty
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.create_trip_title"))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("trip_planner.loading")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.basics.title"),
                                subtitle: String(localized: "trip_planner.basics.subtitle")
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    TripPlannerTextInput(
                                        title: String(localized: "trip_planner.trip_name"),
                                        text: $title,
                                        placeholder: String(localized: "trip_planner.trip_name_placeholder")
                                    )

                                    TripPlannerTextInput(
                                        title: String(localized: "trip_planner.notes"),
                                        text: $notes,
                                        placeholder: String(localized: "trip_planner.notes_placeholder"),
                                        axis: .vertical
                                    )

                                    Toggle("trip_planner.add_tentative_dates", isOn: $includeDates)
                                        .tint(.black)

                                    if includeDates {
                                        DatePicker("trip_planner.start", selection: $startDate, displayedComponents: .date)
                                            .tint(.black)

                                        DatePicker("trip_planner.end", selection: $endDate, in: startDate..., displayedComponents: .date)
                                            .tint(.black)

                                        Button {
                                            Task {
                                                await openDraftCalendar()
                                            }
                                        } label: {
                                            Label("trip_planner.preview_calendar", systemImage: "calendar.badge.plus")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.black)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color.white.opacity(0.82))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.whos_going.title"),
                                subtitle: String(localized: "trip_planner.whos_going.subtitle")
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle("trip_planner.plan_with_friends", isOn: $includeFriends)
                                        .tint(.black)

                                    if includeFriends {
                                        if !sessionManager.isAuthenticated {
                                            TripPlannerInfoCard(
                                                text: String(localized: "trip_planner.friend_matching_locked"),
                                                systemImage: "lock.fill"
                                            )
                                        } else if let friendsError {
                                            TripPlannerInfoCard(
                                                text: friendsError,
                                                systemImage: "exclamationmark.triangle.fill"
                                            )
                                        } else if friends.isEmpty {
                                            TripPlannerInfoCard(
                                                text: String(localized: "trip_planner.no_friends_yet"),
                                                systemImage: "person.2.slash"
                                            )
                                        } else {
                                            HStack {
                                                Text("trip_planner.travel_friends")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.black)

                                                Spacer()

                                                if rankedFriends.count > 3 {
                                                    Button("trip_planner.see_more") {
                                                        showingAllFriends = true
                                                    }
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.black)
                                                }
                                            }

                                            LazyVStack(spacing: 10) {
                                                ForEach(friendPreview) { friend in
                                                    Button {
                                                        toggleFriend(friend.id)
                                                    } label: {
                                                        TripPlannerFriendRow(
                                                            profile: friend,
                                                            isSelected: selectedFriendIds.contains(friend.id),
                                                            displayName: displayName(for: friend),
                                                            mutualBucketCount: mutualBucketCount(for: friend.id)
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }

                                            if isLoadingShared {
                                                ProgressView("trip_planner.comparing_bucket_lists")
                                                    .tint(.black)
                                            }
                                        }
                                    }
                                }
                            }

                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.countries.title"),
                                subtitle: String(localized: "trip_planner.countries.subtitle")
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    if !selectedCountries.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("trip_planner.included_in_trip")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black)

                                            TripPlannerChipGrid(
                                                items: selectedCountries.map { country in
                                                    TripPlannerChipItem(
                                                        id: country.id,
                                                        title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                        isSelected: true
                                                    )
                                                },
                                                onTap: { item in
                                                    toggleCountry(item.id)
                                                }
                                            )
                                        }
                                    } else {
                                        TripPlannerInfoCard(
                                            text: String(localized: "trip_planner.pick_country_before_save"),
                                            systemImage: "mappin.and.ellipse"
                                        )
                                    }

                                    if !sharedCountries.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text("trip_planner.shared_bucket_matches")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.black)

                                                Spacer()

                                                Button("trip_planner.add_all") {
                                                    selectedCountryIds.formUnion(sharedCountryIds)
                                                }
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.black)
                                            }

                                            TripPlannerChipGrid(
                                                items: sharedCountries.map { country in
                                                    TripPlannerChipItem(
                                                        id: country.id,
                                                        title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                        isSelected: false
                                                    )
                                                },
                                                onTap: { item in
                                                    toggleCountry(item.id)
                                                }
                                            )
                                        }
                                    }

                                    Button {
                                        showingBucketCountries = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .bold))

                                            Text("trip_planner.add_more_countries")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.82))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pageHorizontalInset)
                        .padding(.top, 18)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                saveTrip()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(canSave ? .black : .black.opacity(0.35))
            .disabled(!canSave)
        }
        .sheet(item: $calendarDraft) { draft in
            TripPlannerCalendarSheet(draft: draft)
        }
        .sheet(isPresented: $showingAllFriends) {
            NavigationStack {
                TripPlannerFriendPickerSheet(
                    friends: rankedFriends,
                    selectedIds: selectedFriendIds,
                    displayName: displayName(for:),
                    mutualBucketCount: mutualBucketCount(for:),
                    onToggle: toggleFriend
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBucketCountries) {
            NavigationStack {
                TripPlannerCountryPickerSheet(
                    title: String(localized: "trip_planner.add_countries"),
                    sections: countryPickerSections,
                    selectedIds: selectedCountryIds,
                    bucketIds: Set(countryBucketMatchCounts.keys),
                    sharedIds: sharedCountryIds,
                    onTap: toggleCountry
                )
            }
            .presentationDragIndicator(.visible)
        }
        .alert(String(localized: "trip_planner.calendar_access"), isPresented: Binding(
            get: { calendarError != nil },
            set: { newValue in
                if !newValue {
                    calendarError = nil
                }
            }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(calendarError ?? "")
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedFriendIds) { _, _ in
            Task {
                await loadMissingFriendBuckets()
            }
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
        .onChange(of: includeFriends) { _, enabled in
            if !enabled {
                selectedFriendIds.removeAll()
            }
        }
    }

    @MainActor
    private func loadData() async {
        if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
            countries = cached
        }

        bucketCountryIds = bucketListStore.ids

        async let freshCountriesTask = CountryAPI.refreshCountriesIfNeeded(minInterval: 60)

        if let userId = sessionManager.userId {
            if let bucketIds = try? await profileService.fetchBucketListCountries(userId: userId) {
                bucketCountryIds = bucketIds
            }

            do {
                friends = try await friendService.fetchFriends(for: userId)
                await loadFriendBuckets(for: friends.map(\.id))
            } catch {
                friendsError = String(localized: "trip_planner.friends.load_error")
            }
        }

        if let freshCountries = await freshCountriesTask, !freshCountries.isEmpty {
            countries = freshCountries
        }

        isLoading = false
    }

    @MainActor
    private func loadMissingFriendBuckets() async {
        guard includeFriends, !selectedFriendIds.isEmpty else { return }

        let missing = selectedFriendIds.filter { friendBucketLists[$0] == nil }
        guard !missing.isEmpty else { return }

        isLoadingShared = true
        defer { isLoadingShared = false }

        await loadFriendBuckets(for: Array(missing))
    }

    private func displayName(for profile: Profile) -> String {
        let trimmed = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? profile.username : trimmed
    }

    private func mutualBucketCount(for friendId: UUID) -> Int {
        bucketCountryIds.intersection(friendBucketLists[friendId] ?? []).count
    }

    @MainActor
    private func loadFriendBuckets(for friendIds: [UUID]) async {
        guard !friendIds.isEmpty else { return }

        for friendId in friendIds {
            guard friendBucketLists[friendId] == nil else { continue }
            friendBucketLists[friendId] = (try? await profileService.fetchBucketListCountries(userId: friendId)) ?? []
        }
    }

    private func toggleCountry(_ id: String) {
        if selectedCountryIds.contains(id) {
            selectedCountryIds.remove(id)
        } else {
            selectedCountryIds.insert(id)
        }
    }

    private func toggleFriend(_ id: UUID) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
    }

    private func resolvedTripTitle() -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        if let firstCountry = selectedCountries.first {
            return String(format: String(localized: "trip_planner.generated_title_format"), locale: Locale.current, firstCountry.localizedDisplayName)
        }

        return String(localized: "trip_planner.new_trip")
    }

    @MainActor
    private func openDraftCalendar() async {
        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                calendarError = String(localized: "trip_planner.calendar_error_denied")
                return
            }

            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
            event.title = resolvedTripTitle()
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: startDate)
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            event.notes = notes
            calendarDraft = TripPlannerCalendarDraft(store: store, event: event)
        } catch {
            calendarError = error.localizedDescription
        }
    }

    private func saveTrip() {
        let trip = TripPlannerTrip(
            id: existingTrip?.id ?? UUID(),
            createdAt: existingTrip?.createdAt ?? Date(),
            title: resolvedTripTitle(),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: includeDates ? startDate : nil,
            endDate: includeDates ? endDate : nil,
            countryIds: selectedCountries.map(\.id),
            countryNames: selectedCountries.map(\.name),
            friendIds: selectedFriends.map(\.id),
            friendNames: selectedFriends.map(displayName),
            friends: selectedFriends.map(friendSnapshot),
            availability: existingTrip?.availability ?? defaultAvailability(),
            dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                existingPlans: existingTrip?.dayPlans ?? [],
                startDate: includeDates ? startDate : nil,
                endDate: includeDates ? endDate : nil,
                countries: selectedCountries.map { ($0.id, $0.name) }
            ),
            expenses: existingTrip?.expenses ?? []
        )

        onSave(trip)
        dismiss()
    }

    private func friendSnapshot(for profile: Profile) -> TripPlannerFriendSnapshot {
        TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: displayName(for: profile),
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private func defaultAvailability() -> [TripPlannerAvailabilityProposal] {
        guard includeDates else { return [] }
        return [
            TripPlannerAvailabilityProposal(
                id: UUID(),
                participantId: "self",
                participantName: String(localized: "trip_planner.you"),
                participantUsername: nil,
                participantAvatarURL: nil,
                kind: .exactDates,
                startDate: startDate,
                endDate: endDate
            )
        ]
    }
}

private struct TripPlannerDetailView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void
    let onDelete: () -> Void
    let onAddToCalendar: (TripPlannerTrip) -> Void

    @State private var resolvedFriends: [TripPlannerFriendSnapshot]
    @State private var isLoadingFriendProfiles = false
    @State private var resolvedCountries: [Country] = []
    @State private var currentUserSnapshot: TripPlannerFriendSnapshot?
    @State private var currentPassportPreferences: PassportPreferences = .empty
    @State private var travelerPassportPreferences: [UUID: PassportPreferences] = [:]
    @State private var travelerProfiles: [UUID: Profile] = [:]
    @State private var groupLanguageScoresByCountry: [String: Int] = [:]
    @State private var groupVisaNeeds: [TripPlannerTravelerVisaNeed] = []

    private let profileService = ProfileService(supabase: SupabaseManager.shared)
    private let visaStore = VisaRequirementsStore.shared
    private let scoreWeightsStore = ScoreWeightsStore()

    init(
        trip: TripPlannerTrip,
        onSave: @escaping (TripPlannerTrip) -> Void,
        onDelete: @escaping () -> Void,
        onAddToCalendar: @escaping (TripPlannerTrip) -> Void
    ) {
        _trip = State(initialValue: trip)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAddToCalendar = onAddToCalendar
        _resolvedFriends = State(initialValue: trip.friends)
    }

    private var tripContentRefreshKey: String {
        let startInterval = trip.startDate?.timeIntervalSince1970 ?? 0
        let endInterval = trip.endDate?.timeIntervalSince1970 ?? 0
        let countryKey = trip.countryIds.joined(separator: ",")
        let friendKey = trip.friendIds.map(\.uuidString).joined(separator: ",")
        return "\(trip.id.uuidString)|\(startInterval)|\(endInterval)|\(countryKey)|\(friendKey)"
    }

    private func saveTripChanges(_ updatedTrip: TripPlannerTrip) {
        trip = updatedTrip
        onSave(updatedTrip)
    }

    private var displayedFriends: [TripPlannerFriendSnapshot] {
        resolvedFriends.isEmpty ? trip.friends : resolvedFriends
    }

    private var displayedTravelers: [TripPlannerFriendSnapshot] {
        var travelers: [TripPlannerFriendSnapshot] = []

        if let currentUserSnapshot {
            travelers.append(currentUserSnapshot)
        }

        travelers.append(contentsOf: displayedFriends)
        return travelers
    }

    private var displayedCountries: [Country] {
        resolvedCountries.isEmpty ? trip.countryIds.enumerated().map { index, id in
            Country(
                iso2: id,
                name: CountrySelectionFormatter.localizedName(for: id),
                score: nil
            )
        } : resolvedCountries
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(trip.title)

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerEditableSectionCard(
                            title: String(localized: "trip_planner.detail.trip_details"),
                            subtitle: trip.isGroupTrip ? String(localized: "trip_planner.detail.group_trip") : String(localized: "trip_planner.detail.solo_trip")
                        ) {
                            NavigationLink {
                                TripPlannerBasicsEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("common.edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            VStack(alignment: .leading, spacing: 12) {
                                if let rangeText = TripPlannerDateFormatter.rangeText(start: trip.startDate, end: trip.endDate) {
                                    Label(rangeText, systemImage: "calendar")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.black)
                                }

                                if !trip.notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("trip_planner.notes")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.75))

                                        Text(trip.notes)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.black)
                                    }
                                }
                            }
                        }

                        TripPlannerEditableSectionCard(
                            title: String(localized: "trip_planner.whos_going.title"),
                            subtitle: displayedTravelers.isEmpty ? String(localized: "trip_planner.detail.just_you_for_now") : String(localized: "trip_planner.detail.everyone_included")
                        ) {
                            NavigationLink {
                                TripPlannerFriendsEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("common.edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            if displayedTravelers.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.detail.no_friends_added"),
                                    systemImage: "person"
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    if isLoadingFriendProfiles && displayedFriends.isEmpty {
                                        ProgressView("trip_planner.detail.loading_profiles")
                                            .tint(.black)
                                    }

                                    ForEach(displayedTravelers) { friend in
                                        Group {
                                            if friend.id == sessionManager.userId {
                                                TripPlannerSelectedFriendCard(friend: friend)
                                            } else {
                                                NavigationLink {
                                                    TripPlannerProfileDestinationView(userId: friend.id)
                                                } label: {
                                                    TripPlannerSelectedFriendCard(friend: friend)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TripPlannerEditableSectionCard(
                            title: String(localized: "trip_planner.countries.title"),
                            subtitle: String(localized: "trip_planner.detail.countries_subtitle")
                        ) {
                            NavigationLink {
                                TripPlannerCountriesEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("common.edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            TripPlannerCountryNavigationGrid(countries: displayedCountries)
                        }

                        TripPlannerEditableSectionCard(
                            title: String(localized: "trip_planner.expenses.title"),
                            subtitle: String(localized: "trip_planner.expenses.subtitle")
                        ) {
                            NavigationLink {
                                TripPlannerExpensesEditorView(
                                    trip: trip,
                                    participants: displayedTravelers,
                                    onSave: saveTripChanges
                                )
                            } label: {
                                Text("common.edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            TripPlannerExpensesSection(
                                expenses: trip.expenses,
                                participants: displayedTravelers
                            )
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.detail.trip_stats"),
                            subtitle: String(localized: "trip_planner.detail.trip_stats_subtitle")
                        ) {
                            TripPlannerStatsSection(
                                countries: displayedCountries,
                                startDate: trip.startDate,
                                endDate: trip.endDate,
                                tripDayPlans: trip.dayPlans,
                                weights: scoreWeightsStore.weights,
                                preferredMonth: scoreWeightsStore.selectedMonth,
                                isGroupTrip: trip.isGroupTrip,
                                travelerCount: displayedTravelers.count,
                                passportLabel: tripPassportLabel,
                                groupLanguageScoresByCountry: groupLanguageScoresByCountry,
                                groupVisaNeeds: groupVisaNeeds
                            )
                        }

                        TripPlannerEditableSectionCard(
                            title: String(localized: "trip_planner.availability.title"),
                            subtitle: trip.isGroupTrip ? String(localized: "trip_planner.detail.availability_group_subtitle") : String(localized: "trip_planner.detail.availability_solo_subtitle")
                        ) {
                            NavigationLink {
                                TripPlannerAvailabilityEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("common.edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            TripPlannerAvailabilitySection(trip: trip)
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.actions.title"),
                            subtitle: String(localized: "trip_planner.actions.subtitle")
                        ) {
                            VStack(spacing: 12) {
                                if trip.startDate != nil, trip.endDate != nil {
                                    Button {
                                        onAddToCalendar(trip)
                                    } label: {
                                        Label("trip_planner.actions.add_to_calendar", systemImage: "calendar.badge.plus")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.white.opacity(0.84))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label("trip_planner.actions.delete_trip", systemImage: "trash")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.84))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            EmptyView()
        }
        .task(id: tripContentRefreshKey) {
            await loadTravelerProfiles()
            await loadCountryStats()
            await loadGroupLanguageScores()
        }
    }

    @MainActor
    private func loadTravelerProfiles() async {
        isLoadingFriendProfiles = true
        defer { isLoadingFriendProfiles = false }

        var refreshed: [TripPlannerFriendSnapshot] = []
        var profilesByID: [UUID: Profile] = [:]
        var passportPreferencesByUserID: [UUID: PassportPreferences] = [:]

        if let currentUserId = sessionManager.userId {
            if let cached = profileService.cachedProfile(userId: currentUserId) {
                profilesByID[currentUserId] = cached
                currentUserSnapshot = friendSnapshot(from: cached)
            } else if let profile = try? await profileService.fetchMyProfile(userId: currentUserId) {
                profilesByID[currentUserId] = profile
                currentUserSnapshot = friendSnapshot(from: profile)
            }

            if let cachedPreferences = profileService.cachedPassportPreferences(userId: currentUserId) {
                currentPassportPreferences = cachedPreferences
                passportPreferencesByUserID[currentUserId] = cachedPreferences
            } else if let preferences = try? await profileService.fetchPassportPreferences(userId: currentUserId) {
                currentPassportPreferences = preferences
                passportPreferencesByUserID[currentUserId] = preferences
            }
        }

        for snapshot in trip.friends {
            if let cached = profileService.cachedProfile(userId: snapshot.id) {
                profilesByID[snapshot.id] = cached
                refreshed.append(friendSnapshot(from: cached))
            } else {
                do {
                    let profile = try await profileService.fetchMyProfile(userId: snapshot.id)
                    profilesByID[snapshot.id] = profile
                    refreshed.append(friendSnapshot(from: profile))
                } catch {
                    refreshed.append(snapshot)
                }
            }

            if let cachedPreferences = profileService.cachedPassportPreferences(userId: snapshot.id) {
                passportPreferencesByUserID[snapshot.id] = cachedPreferences
            } else if let preferences = try? await profileService.fetchPassportPreferences(userId: snapshot.id) {
                passportPreferencesByUserID[snapshot.id] = preferences
            }
        }

        travelerProfiles = profilesByID
        travelerPassportPreferences = passportPreferencesByUserID

        if !refreshed.isEmpty {
            resolvedFriends = refreshed
        }
    }

    private func friendSnapshot(from profile: Profile) -> TripPlannerFriendSnapshot {
        let trimmed = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: trimmed.isEmpty ? profile.username : trimmed,
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private var tripPassportLabel: String {
        if currentPassportPreferences.nationalityCountryCodes.count > 1 {
            return String(localized: "trip_planner.visa.best_saved_passport")
        }

        if let code = currentPassportPreferences.effectivePassportCountryCode {
            return CountrySelectionFormatter.localizedName(for: code)
        }

        return visaStore.activePassportLabel ?? String(localized: "trip_planner.visa.default_passport_label")
    }

    @MainActor
    private func loadCountryStats() async {
        var countries = CountryAPI.loadCachedCountries() ?? []

        if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
            countries = fresh
        }

        let selected = countries
            .filter { trip.countryIds.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsIndex = trip.countryIds.firstIndex(of: lhs.id) ?? 0
                let rhsIndex = trip.countryIds.firstIndex(of: rhs.id) ?? 0
                return lhsIndex < rhsIndex
            }

        guard !selected.isEmpty else {
            resolvedCountries = []
            groupVisaNeeds = []
            return
        }

        let hydratedCountries = await visaStore.hydrate(
            countries: selected,
            passportCountryCodes: currentPassportPreferences.nationalityCountryCodes,
            fallbackPassportCountryCode: currentPassportPreferences.effectivePassportCountryCode
        )
        resolvedCountries = hydratedCountries

        let travelers = displayedTravelers
        var needs: [TripPlannerTravelerVisaNeed] = []

        for traveler in travelers {
            let preferences = travelerPassportPreferences[traveler.id] ?? .empty
            let travelerCountries = await visaStore.hydrate(
                countries: selected,
                passportCountryCodes: preferences.nationalityCountryCodes,
                fallbackPassportCountryCode: preferences.effectivePassportCountryCode
            )

            for country in travelerCountries {
                guard let visaType = country.visaType else { continue }

                let needsAdvanceVisa = ["evisa", "visa_required", "entry_permit", "ban"].contains(visaType)
                let exceedsAllowedStay = {
                    guard
                        let tripLengthDays = tripLengthDays,
                        let allowedDays = country.visaAllowedDays
                    else {
                        return false
                    }

                    return tripLengthDays > allowedDays
                }()

                guard needsAdvanceVisa || exceedsAllowedStay else { continue }

                needs.append(
                    TripPlannerTravelerVisaNeed(
                        travelerId: traveler.id,
                        travelerName: traveler.displayName,
                        countryID: country.id,
                        countryName: country.localizedDisplayName,
                        countryFlag: country.flagEmoji,
                        passportLabel: country.visaRecommendedPassportLabel ?? country.visaPassportLabel ?? resolvedPassportLabel(for: preferences),
                        visaType: visaType,
                        allowedDays: country.visaAllowedDays,
                        exceedsAllowedStay: exceedsAllowedStay
                    )
                )
            }
        }

        groupVisaNeeds = needs.sorted { lhs, rhs in
            if lhs.travelerName != rhs.travelerName {
                return lhs.travelerName.localizedCaseInsensitiveCompare(rhs.travelerName) == .orderedAscending
            }

            return lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
        }
    }

    private var tripLengthDays: Int? {
        guard let startDate = trip.startDate, let endDate = trip.endDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day ?? 0
        return max(days + 1, 1)
    }

    private func resolvedPassportLabel(for preferences: PassportPreferences) -> String {
        if let code = preferences.effectivePassportCountryCode {
            return CountrySelectionFormatter.localizedName(for: code)
        }

        return String(localized: "trip_planner.visa.saved_passport")
    }

    @MainActor
    private func loadGroupLanguageScores() async {
        let countries = displayedCountries
        guard !countries.isEmpty else {
            groupLanguageScoresByCountry = [:]
            return
        }

        let allTravelerLanguages = travelerProfiles.values.flatMap(\.languages)
        guard !allTravelerLanguages.isEmpty else {
            groupLanguageScoresByCountry = [:]
            return
        }

        var scores: [String: Int] = [:]

        for country in countries {
            do {
                guard let languageProfile = try await TripPlannerCountryLanguageProfileStore.shared.profile(for: country.iso2) else {
                    continue
                }

                if let score = TripPlannerGroupLanguageCompatibilityScorer.score(
                    travelerLanguages: allTravelerLanguages,
                    countryProfile: languageProfile
                ) {
                    scores[country.id] = score
                }
            } catch {
                continue
            }
        }

        groupLanguageScoresByCountry = scores
    }
}

private struct TripPlannerBasicsEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var includeDates: Bool
    @State private var startDate: Date
    @State private var endDate: Date

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _title = State(initialValue: trip.title)
        _notes = State(initialValue: trip.notes)
        _includeDates = State(initialValue: trip.startDate != nil || trip.endDate != nil)
        _startDate = State(initialValue: trip.startDate ?? Date())
        _endDate = State(initialValue: trip.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: trip.startDate ?? Date()) ?? Date())
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.detail.trip_details"))

                ScrollView {
                    TripPlannerSectionCard(
                        title: String(localized: "trip_planner.detail.basics"),
                        subtitle: String(localized: "trip_planner.detail.basics_subtitle")
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            TripPlannerTextInput(
                                title: String(localized: "trip_planner.trip_name"),
                                text: $title,
                                placeholder: String(localized: "trip_planner.trip_name_placeholder")
                            )

                            TripPlannerTextInput(
                                title: String(localized: "trip_planner.notes"),
                                text: $notes,
                                placeholder: String(localized: "trip_planner.notes_placeholder"),
                                axis: .vertical
                            )

                            Toggle("trip_planner.add_tentative_dates", isOn: $includeDates)
                                .tint(.black)

                            if includeDates {
                                DatePicker("trip_planner.start", selection: $startDate, displayedComponents: .date)
                                    .tint(.black)

                                DatePicker("trip_planner.end", selection: $endDate, in: startDate..., displayedComponents: .date)
                                    .tint(.black)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trip.title : title.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        startDate: includeDates ? startDate : nil,
                        endDate: includeDates ? endDate : nil,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        availability: updatedAvailability(),
                        dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                            existingPlans: trip.dayPlans,
                            startDate: includeDates ? startDate : nil,
                            endDate: includeDates ? endDate : nil,
                            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
                        ),
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
    }

    private func updatedAvailability() -> [TripPlannerAvailabilityProposal] {
        let nonSelf = trip.availability.filter { $0.participantId != "self" }
        guard includeDates else { return nonSelf }

        return nonSelf + [
            TripPlannerAvailabilityProposal(
                id: UUID(),
                participantId: "self",
                participantName: String(localized: "trip_planner.you"),
                participantUsername: nil,
                participantAvatarURL: nil,
                kind: .exactDates,
                startDate: startDate,
                endDate: endDate
            )
        ]
    }
}

private struct TripPlannerFriendsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var friends: [Profile] = []
    @State private var selectedFriendIds: Set<UUID>
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let friendService = FriendService()

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _selectedFriendIds = State(initialValue: Set(trip.friendIds))
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.whos_going.title"))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("trip_planner.friends.loading")
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.travel_friends"),
                                subtitle: String(localized: "trip_planner.friends.subtitle")
                            ) {
                                if let errorMessage {
                                    TripPlannerInfoCard(
                                        text: errorMessage,
                                        systemImage: "exclamationmark.triangle.fill"
                                    )
                                } else if friends.isEmpty {
                                    TripPlannerInfoCard(
                                        text: String(localized: "trip_planner.friends.none_added_yet"),
                                        systemImage: "person.2.slash"
                                    )
                                } else {
                                    LazyVStack(spacing: 10) {
                                        ForEach(friends.sorted(by: { displayName(for: $0) < displayName(for: $1) })) { friend in
                                            Button {
                                                toggle(friend.id)
                                            } label: {
                                                TripPlannerFriendRow(
                                                    profile: friend,
                                                    isSelected: selectedFriendIds.contains(friend.id),
                                                    displayName: displayName(for: friend)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.pageHorizontalInset)
                            .padding(.top, 18)
                            .padding(.bottom, 32)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                let selectedFriends = friends
                    .filter { selectedFriendIds.contains($0.id) }
                    .sorted { displayName(for: $0) < displayName(for: $1) }

                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: selectedFriends.map(\.id),
                        friendNames: selectedFriends.map(displayName),
                        friends: selectedFriends.map(friendSnapshot),
                        availability: preservedAvailability(with: selectedFriends.map(friendSnapshot)),
                        dayPlans: trip.dayPlans,
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .task {
            await loadFriends()
        }
    }

    @MainActor
    private func loadFriends() async {
        defer { isLoading = false }

        guard let userId = sessionManager.userId else {
            errorMessage = String(localized: "trip_planner.friends.sign_in_required")
            return
        }

        do {
            friends = try await friendService.fetchFriends(for: userId)
        } catch {
            errorMessage = String(localized: "trip_planner.friends.load_error")
        }
    }

    private func toggle(_ id: UUID) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
    }

    private func displayName(for profile: Profile) -> String {
        let trimmed = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? profile.username : trimmed
    }

    private func friendSnapshot(for profile: Profile) -> TripPlannerFriendSnapshot {
        TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: displayName(for: profile),
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private func preservedAvailability(with selectedFriends: [TripPlannerFriendSnapshot]) -> [TripPlannerAvailabilityProposal] {
        let validIds = Set(selectedFriends.map { String($0.id.uuidString) }).union(["self"])
        return trip.availability.filter { validIds.contains($0.participantId) }
    }
}

private struct TripPlannerAvailabilityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var proposals: [TripPlannerAvailabilityProposal]
    @State private var selectedKind: TripPlannerAvailabilityKind = .exactDates
    @State private var rangeStart = Date()
    @State private var rangeEnd = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
    @State private var selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
    @State private var editingProposalId: UUID?
    @State private var dayPlans: [TripPlannerDayPlan]

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _proposals = State(initialValue: trip.availability.sorted { $0.startDate < $1.startDate })
        _dayPlans = State(initialValue: TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
        ))
    }

    private var participants: [TripPlannerAvailabilityParticipant] {
        trip.availabilityParticipants
    }

    private var currentParticipant: TripPlannerAvailabilityParticipant {
        participants.first(where: { $0.id == "self" }) ?? .you
    }

    private var overlapMatches: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip, proposals: proposals)
    }

    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let start = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    private var countryOptions: [(id: String, name: String)] {
        zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.availability.title"))

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.availability.how_it_works_title"),
                            subtitle: String(localized: "trip_planner.availability.how_it_works_subtitle")
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.availability.info_exact_vs_flexible"),
                                    systemImage: "calendar"
                                )

                                if overlapMatches.isEmpty {
                                    TripPlannerInfoCard(
                                        text: String(localized: "trip_planner.availability.no_shared_window"),
                                        systemImage: "person.3.sequence.fill"
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(overlapMatches.prefix(2)) { overlap in
                                            TripPlannerOverlapCard(overlap: overlap)
                                        }
                                    }
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.availability.current_proposals_title"),
                            subtitle: String(localized: "trip_planner.availability.current_proposals_subtitle")
                        ) {
                            if proposals.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.availability.none_proposed"),
                                    systemImage: "calendar.badge.plus"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(Array(groupedProposals().enumerated()), id: \.1.participant.id) { index, group in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .fill(TripPlannerAvailabilityTheme.color(for: group.participant.id, index: index))
                                                    .frame(width: 10, height: 10)

                                                TripPlannerAvatarView(
                                                    name: group.participant.name,
                                                    username: group.participant.username ?? group.participant.name,
                                                    avatarURL: group.participant.avatarURL,
                                                    size: 34
                                                )

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(group.participant.name)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.black)

                                                    if let username = group.participant.username {
                                                        Text("@\(username)")
                                                            .font(.caption)
                                                            .foregroundStyle(.black.opacity(0.62))
                                                    }
                                                }
                                            }

                                            ForEach(group.proposals) { proposal in
                                                HStack(spacing: 10) {
                                                    TripPlannerProposalChip(
                                                        proposal: proposal,
                                                        color: TripPlannerAvailabilityTheme.color(for: group.participant.id, index: index)
                                                    )

                                                    Spacer()

                                                    if proposal.participantId == "self" {
                                                        Button {
                                                            beginEditing(proposal)
                                                        } label: {
                                                            Text("common.edit")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundStyle(.black)
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 8)
                                                                .background(Capsule().fill(Color.white.opacity(0.86)))
                                                        }
                                                        .buttonStyle(.plain)

                                                        Button(role: .destructive) {
                                                            proposals.removeAll { $0.id == proposal.id }
                                                            if editingProposalId == proposal.id {
                                                                resetComposer()
                                                            }
                                                        } label: {
                                                            Image(systemName: "trash")
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundStyle(.black)
                                                                .padding(8)
                                                                .background(Circle().fill(Color.white.opacity(0.82)))
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color.white.opacity(0.72))
                                        )
                                    }
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: editingProposalId == nil ? String(localized: "trip_planner.availability.your_availability") : String(localized: "trip_planner.availability.edit_your_availability"),
                            subtitle: editingProposalId == nil
                                ? String(localized: "trip_planner.availability.your_availability_subtitle")
                                : String(localized: "trip_planner.availability.edit_your_availability_subtitle")
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    TripPlannerAvatarView(
                                        name: currentParticipant.name,
                                        username: currentParticipant.username ?? currentParticipant.name,
                                        avatarURL: currentParticipant.avatarURL,
                                        size: 42
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(currentParticipant.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)

                                        Text("trip_planner.availability.only_you_can_edit")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.black.opacity(0.62))
                                    }
                                }

                                Picker(String(localized: "trip_planner.itinerary.type"), selection: $selectedKind) {
                                    ForEach(TripPlannerAvailabilityKind.allCases) { kind in
                                        Text(kind.title).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if selectedKind == .exactDates {
                                    DatePicker("trip_planner.start", selection: $rangeStart, displayedComponents: .date)
                                        .tint(.black)

                                    DatePicker("trip_planner.end", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                                        .tint(.black)
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("trip_planner.availability.month")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.black.opacity(0.72))

                                        Picker(String(localized: "trip_planner.availability.month"), selection: $selectedMonth) {
                                            ForEach(monthOptions, id: \.self) { month in
                                                Text(TripPlannerAvailabilityCalculator.monthTitle(for: month)).tag(month)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.78))
                                        )
                                    }
                                }

                                Button {
                                    saveProposal()
                                } label: {
                                    Label(editingProposalId == nil ? String(localized: "trip_planner.availability.save") : String(localized: "trip_planner.availability.update"), systemImage: editingProposalId == nil ? "plus" : "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.84))
                                        )
                                }
                                .buttonStyle(.plain)

                                if editingProposalId != nil {
                                    Button("trip_planner.availability.cancel_editing") {
                                        resetComposer()
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.75))
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.availability.trip_route_title"),
                            subtitle: trip.startDate != nil && trip.endDate != nil
                                ? String(localized: "trip_planner.availability.trip_route_subtitle")
                                : String(localized: "trip_planner.availability.trip_route_missing_dates")
                        ) {
                            if dayPlans.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.availability.trip_route_empty"),
                                    systemImage: "calendar.badge.plus"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(dayPlans.indices, id: \.self) { index in
                                        TripPlannerDayPlanEditorRow(
                                            plan: Binding(
                                                get: { dayPlans[index] },
                                                set: { dayPlans[index] = $0 }
                                            ),
                                            countryOptions: countryOptions
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        availability: proposals.sorted { $0.startDate < $1.startDate },
                        dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                            existingPlans: dayPlans,
                            startDate: trip.startDate,
                            endDate: trip.endDate,
                            countries: countryOptions
                        ),
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .onChange(of: rangeStart) { _, newValue in
            if rangeEnd < newValue {
                rangeEnd = newValue
            }
        }
    }

    private func groupedProposals() -> [(participant: TripPlannerAvailabilityParticipant, proposals: [TripPlannerAvailabilityProposal])] {
        participants.compactMap { participant in
            let matches = proposals.filter { $0.participantId == participant.id }.sorted { $0.startDate < $1.startDate }
            guard !matches.isEmpty else { return nil }
            return (participant, matches)
        }
    }

    private func saveProposal() {
        let proposal = composedProposal(id: editingProposalId ?? UUID())

        if let editingProposalId, let index = proposals.firstIndex(where: { $0.id == editingProposalId }) {
            proposals[index] = proposal
        } else {
            proposals.append(proposal)
        }
        proposals.sort { $0.startDate < $1.startDate }
        resetComposer()
    }

    private func beginEditing(_ proposal: TripPlannerAvailabilityProposal) {
        editingProposalId = proposal.id
        selectedKind = proposal.kind

        if proposal.kind == .exactDates {
            rangeStart = proposal.startDate
            rangeEnd = proposal.endDate
        } else {
            selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: proposal.startDate)
        }
    }

    private func resetComposer() {
        editingProposalId = nil
        selectedKind = .exactDates
        rangeStart = Date()
        rangeEnd = Calendar.current.date(byAdding: .day, value: 5, to: rangeStart) ?? rangeStart
        selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
    }

    private func composedProposal(id: UUID) -> TripPlannerAvailabilityProposal {
        if selectedKind == .exactDates {
            return TripPlannerAvailabilityProposal(
                id: id,
                participantId: "self",
                participantName: currentParticipant.name,
                participantUsername: currentParticipant.username,
                participantAvatarURL: currentParticipant.avatarURL,
                kind: .exactDates,
                startDate: rangeStart,
                endDate: rangeEnd
            )
        } else {
            let monthStart = TripPlannerAvailabilityCalculator.startOfMonth(for: selectedMonth)
            return TripPlannerAvailabilityProposal(
                id: id,
                participantId: "self",
                participantName: currentParticipant.name,
                participantUsername: currentParticipant.username,
                participantAvatarURL: currentParticipant.avatarURL,
                kind: .flexibleMonth,
                startDate: monthStart,
                endDate: TripPlannerAvailabilityCalculator.endOfMonth(for: monthStart)
            )
        }
    }
}

private struct TripPlannerCountriesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bucketListStore: BucketListStore

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var sharedBucketCountryIds: Set<String> = []
    @State private var countries: [Country] = []
    @State private var selectedCountryIds: Set<String>
    @State private var searchText = ""
    @State private var isLoading = true

    private let profileService = ProfileService(supabase: SupabaseManager.shared)

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _selectedCountryIds = State(initialValue: Set(trip.countryIds))
    }

    private var visibleCountries: [Country] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = trimmed.normalizedSearchKey
        let filtered = countries.filter { country in
            guard !trimmed.isEmpty else { return true }
            return country.localizedSearchableNames.contains {
                $0.normalizedSearchKey.contains(normalizedSearch)
            }
                || country.id.localizedCaseInsensitiveContains(trimmed)
        }
        return filtered.sorted { $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending }
    }

    private var sharedBucketCountries: [Country] {
        countries
            .filter { sharedBucketCountryIds.contains($0.id) }
            .sorted { $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.countries.title"))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("trip_planner.countries.loading")
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.countries.included_title"),
                                subtitle: String(localized: "trip_planner.countries.included_subtitle")
                            ) {
                                if !sharedBucketCountries.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("trip_planner.countries.mutual_bucket_list")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black)

                                                Spacer()

                                            Button("trip_planner.add_all") {
                                                selectedCountryIds.formUnion(sharedBucketCountryIds)
                                            }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.black)
                                        }

                                        TripPlannerChipGrid(
                                            items: sharedBucketCountries.map { country in
                                                TripPlannerChipItem(
                                                    id: country.id,
                                                    title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                    isSelected: selectedCountryIds.contains(country.id)
                                                )
                                            },
                                            onTap: { item in
                                                toggle(item.id)
                                            }
                                        )
                                    }
                                }

                                TripPlannerTextInput(
                                    title: String(localized: "trip_planner.countries.search_title"),
                                    text: $searchText,
                                    placeholder: String(localized: "trip_planner.countries.search_placeholder")
                                )

                                TripPlannerCountryList(
                                    countries: visibleCountries,
                                    selectedIds: selectedCountryIds,
                                    bucketIds: bucketListStore.ids,
                                    sharedIds: [],
                                    onTap: toggle
                                )
                            }
                            .padding(.horizontal, Theme.pageHorizontalInset)
                            .padding(.top, 18)
                            .padding(.bottom, 32)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                let selectedCountries = countries
                    .filter { selectedCountryIds.contains($0.id) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: selectedCountries.map(\.id),
                        countryNames: selectedCountries.map(\.name),
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        availability: trip.availability,
                        dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                            existingPlans: trip.dayPlans,
                            startDate: trip.startDate,
                            endDate: trip.endDate,
                            countries: selectedCountries.map { ($0.id, $0.name) }
                        ),
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .task {
            await loadCountries()
        }
    }

    @MainActor
    private func loadCountries() async {
        if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
            countries = cached
        }

        await loadSharedBucketCountries()

        if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
            countries = fresh
        }

        countries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false
    }

    @MainActor
    private func loadSharedBucketCountries() async {
        guard !trip.friendIds.isEmpty else {
            sharedBucketCountryIds = []
            return
        }

        var intersection = bucketListStore.ids

        for friendId in trip.friendIds {
            guard let friendBucketIds = try? await profileService.fetchBucketListCountries(userId: friendId) else {
                sharedBucketCountryIds = []
                return
            }
            intersection.formIntersection(friendBucketIds)
        }

        sharedBucketCountryIds = intersection
    }

    private func toggle(_ id: String) {
        if selectedCountryIds.contains(id) {
            selectedCountryIds.remove(id)
        } else {
            selectedCountryIds.insert(id)
        }
    }
}

private struct TripPlannerItineraryPreview: View {
    let trip: TripPlannerTrip

    private var normalizedPlans: [TripPlannerDayPlan] {
        TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
        )
    }

    var body: some View {
        if normalizedPlans.isEmpty {
            TripPlannerInfoCard(
                text: String(localized: "trip_planner.itinerary.preview_empty"),
                systemImage: "calendar.badge.plus"
            )
        } else {
            VStack(spacing: 10) {
                ForEach(Array(normalizedPlans.prefix(4))) { plan in
                    TripPlannerDayPlanRow(plan: plan)
                }

                if normalizedPlans.count > 4 {
                    TripPlannerInfoCard(
                        text: String(
                            format: String(localized: "trip_planner.itinerary.more_days"),
                            locale: Locale.current,
                            normalizedPlans.count - 4
                        ),
                        systemImage: "ellipsis.circle.fill"
                    )
                }
            }
        }
    }
}

private struct TripPlannerItineraryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var dayPlans: [TripPlannerDayPlan]

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _dayPlans = State(initialValue: TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
        ))
    }

    private var countryOptions: [(id: String, name: String)] {
        zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.itinerary.title"))

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.itinerary.day_by_day_title"),
                            subtitle: String(localized: "trip_planner.itinerary.day_by_day_subtitle")
                        ) {
                            VStack(spacing: 10) {
                                ForEach(dayPlans.indices, id: \.self) { index in
                                    TripPlannerDayPlanEditorRow(
                                        plan: binding(for: index),
                                        countryOptions: countryOptions
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pageHorizontalInset)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        availability: trip.availability,
                        dayPlans: normalizedDayPlans(),
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
    }

    private func binding(for index: Int) -> Binding<TripPlannerDayPlan> {
        Binding(
            get: { dayPlans[index] },
            set: { newValue in
                dayPlans[index] = newValue
            }
        )
    }

    private func normalizedDayPlans() -> [TripPlannerDayPlan] {
        dayPlans.sorted { $0.date < $1.date }.map { plan in
            if plan.kind == .travel {
                return TripPlannerDayPlan(id: plan.id, date: plan.date, kind: .travel)
            }

            let matchingCountry = countryOptions.first { $0.id == plan.countryId } ?? countryOptions.first
            return TripPlannerDayPlan(
                id: plan.id,
                date: plan.date,
                kind: matchingCountry == nil ? .travel : .country,
                countryId: matchingCountry?.id,
                countryName: matchingCountry?.name
            )
        }
    }
}

private struct TripPlannerDayPlanEditorRow: View {
    @Binding var plan: TripPlannerDayPlan
    let countryOptions: [(id: String, name: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppDateFormatting.dateString(from: plan.date, dateStyle: .full))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            Picker(String(localized: "trip_planner.itinerary.type"), selection: kindBinding) {
                Text("trip_planner.itinerary.country").tag(TripPlannerDayPlanKind.country)
                Text("trip_planner.itinerary.travel").tag(TripPlannerDayPlanKind.travel)
            }
            .pickerStyle(.segmented)

            if plan.kind == .country {
                Picker(String(localized: "trip_planner.itinerary.country"), selection: countryBinding) {
                    ForEach(countryOptions, id: \.id) { option in
                        Text(option.name).tag(Optional(option.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private var kindBinding: Binding<TripPlannerDayPlanKind> {
        Binding(
            get: { plan.kind },
            set: { newKind in
                if newKind == .travel {
                    plan = TripPlannerDayPlan(id: plan.id, date: plan.date, kind: .travel)
                } else {
                    let country = countryOptions.first
                    plan = TripPlannerDayPlan(
                        id: plan.id,
                        date: plan.date,
                        kind: .country,
                        countryId: country?.id,
                        countryName: country?.name
                    )
                }
            }
        )
    }

    private var countryBinding: Binding<String?> {
        Binding(
            get: { plan.countryId ?? countryOptions.first?.id },
            set: { newCountryID in
                let country = countryOptions.first { $0.id == newCountryID } ?? countryOptions.first
                plan = TripPlannerDayPlan(
                    id: plan.id,
                    date: plan.date,
                    kind: country == nil ? .travel : .country,
                    countryId: country?.id,
                    countryName: country?.name
                )
            }
        )
    }
}

private struct TripPlannerDayPlanRow: View {
    let plan: TripPlannerDayPlan

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateFormatting.dateString(from: plan.date, template: "EEE MMM d"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)

                Text(labelText)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.74))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }

    private var labelText: String {
        if plan.kind == .travel {
            return String(localized: "trip_planner.itinerary.travel_day")
        }
        return plan.countryName ?? String(localized: "trip_planner.itinerary.country_day")
    }
}

private struct TripPlannerExpenseParticipant: Identifiable, Hashable {
    let id: String
    let name: String
    let username: String?

    init(friend: TripPlannerFriendSnapshot) {
        self.id = friend.id.uuidString
        self.name = friend.displayName
        self.username = friend.username
    }
}

private struct TripPlannerExpenseBalance: Identifiable {
    let participantId: String
    let participantName: String
    let amount: Double

    var id: String { participantId }
    var isOwed: Bool { amount > 0.009 }
    var owes: Bool { amount < -0.009 }
}

private struct TripPlannerExpensesSection: View {
    let expenses: [TripPlannerExpense]
    let participants: [TripPlannerFriendSnapshot]

    private var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.totalAmount }
    }

    private var outstandingTotal: Double {
        expenses.flatMap(\.shares).filter { !$0.isPaid }.reduce(0) { $0 + $1.amountOwed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TripPlannerStatPill(
                    title: String(localized: "trip_planner.expenses.stats.total_logged"),
                    value: currency(totalSpent),
                    detail: String(
                        format: String(localized: "trip_planner.expenses.stats.expense_count"),
                        locale: Locale.current,
                        expenses.count
                    )
                )

                TripPlannerStatPill(
                    title: String(localized: "trip_planner.expenses.stats.still_owed"),
                    value: currency(outstandingTotal),
                    detail: outstandingTotal > 0 ? String(localized: "trip_planner.expenses.stats.unpaid_balances") : String(localized: "trip_planner.expenses.stats.everyone_settled")
                )
            }

            if expenses.isEmpty {
                TripPlannerInfoCard(
                    text: String(localized: "trip_planner.expenses.stats.empty"),
                    systemImage: "creditcard"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(expenses.prefix(3)) { expense in
                        TripPlannerExpenseRow(expense: expense, onEdit: nil, onUpdate: nil)
                    }

                    if expenses.count > 3 {
                        TripPlannerInfoCard(
                            text: String(
                                format: String(localized: "trip_planner.expenses.stats.more_expenses"),
                                locale: Locale.current,
                                expenses.count - 3
                            ),
                            systemImage: "ellipsis.circle.fill"
                        )
                    }
                }
            }
        }
    }

    private func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

private struct TripPlannerExpensesEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TripPlannerTrip
    let participants: [TripPlannerFriendSnapshot]
    let onSave: (TripPlannerTrip) -> Void

    @State private var expenses: [TripPlannerExpense]
    @State private var composerPresentation: TripPlannerExpenseComposerPresentation?

    init(
        trip: TripPlannerTrip,
        participants: [TripPlannerFriendSnapshot],
        onSave: @escaping (TripPlannerTrip) -> Void
    ) {
        self.trip = trip
        self.participants = participants
        self.onSave = onSave
        _expenses = State(initialValue: trip.expenses.sorted { $0.date > $1.date })
    }

    private var expenseParticipants: [TripPlannerExpenseParticipant] {
        participants.map(TripPlannerExpenseParticipant.init(friend:))
    }

    private var balances: [TripPlannerExpenseBalance] {
        var totals = Dictionary(uniqueKeysWithValues: expenseParticipants.map { ($0.id, 0.0) })

        for expense in expenses {
            for share in expense.shares where !share.isPaid {
                totals[expense.paidById, default: 0] += share.amountOwed
                totals[share.participantId, default: 0] -= share.amountOwed
            }
        }

        return expenseParticipants.map { participant in
            TripPlannerExpenseBalance(
                participantId: participant.id,
                participantName: participant.name,
                amount: totals[participant.id, default: 0]
            )
        }
        .sorted {
            abs($0.amount) > abs($1.amount)
        }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.expenses.title"))

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.expenses.outstanding_balances"),
                            subtitle: ""
                        ) {
                            if balances.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.expenses.add_people_first"),
                                    systemImage: "person.2"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(balances) { balance in
                                        TripPlannerExpenseBalanceCard(balance: balance)
                                    }
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.expenses.logged_expenses"),
                            subtitle: ""
                        ) {
                            if expenses.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.expenses.none_yet"),
                                    systemImage: "creditcard"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(expenses) { expense in
                                        VStack(spacing: 10) {
                                            TripPlannerExpenseRow(
                                                expense: expense,
                                                onEdit: {
                                                    composerPresentation = TripPlannerExpenseComposerPresentation(expense: expense)
                                                },
                                                onUpdate: { updatedExpense in
                                                    updateExpense(updatedExpense)
                                                }
                                            )

                                            Button(role: .destructive) {
                                                expenses.removeAll { $0.id == expense.id }
                                                persistExpenses()
                                            } label: {
                                                Text("trip_planner.expenses.delete_expense")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.black)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                            .fill(Color.white.opacity(0.74))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }

            if let composerPresentation {
                TripPlannerExpenseComposerOverlay(
                    participants: expenseParticipants,
                    existingExpense: composerPresentation.expense,
                    onClose: {
                        self.composerPresentation = nil
                    },
                    onSaveExpense: { expense in
                        if expenses.contains(where: { $0.id == expense.id }) {
                            updateExpense(expense)
                        } else {
                            expenses.insert(expense, at: 0)
                            persistExpenses()
                        }
                        self.composerPresentation = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: composerPresentation != nil)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            if composerPresentation == nil {
                Button {
                    composerPresentation = TripPlannerExpenseComposerPresentation(expense: nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))

                        Text("trip_planner.expenses.new")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func updateExpense(_ expense: TripPlannerExpense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[index] = expense
        persistExpenses()
    }

    private func persistExpenses() {
        onSave(
            TripPlannerTrip(
                id: trip.id,
                createdAt: trip.createdAt,
                title: trip.title,
                notes: trip.notes,
                startDate: trip.startDate,
                endDate: trip.endDate,
                countryIds: trip.countryIds,
                countryNames: trip.countryNames,
                friendIds: trip.friendIds,
                friendNames: trip.friendNames,
                friends: trip.friends,
                availability: trip.availability,
                dayPlans: trip.dayPlans,
                expenses: expenses.sorted { $0.date > $1.date }
            )
        )
    }
}

private struct TripPlannerExpenseComposerPresentation: Identifiable {
    let id = UUID()
    let expense: TripPlannerExpense?
}

private struct TripPlannerExpenseBalanceCard: View {
    let balance: TripPlannerExpenseBalance

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.participantName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(balanceColor.opacity(0.9))
            }

            Spacer()

            Text(currency(abs(balance.amount)))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(balanceColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(balanceBackground)
        )
    }

    private var statusText: String {
        if balance.isOwed { return String(localized: "trip_planner.expenses.should_receive") }
        if balance.owes { return String(localized: "trip_planner.expenses.still_owes") }
        return String(localized: "trip_planner.expenses.settled_up")
    }

    private var balanceColor: Color {
        if balance.isOwed { return Color(red: 0.12, green: 0.50, blue: 0.25) }
        if balance.owes { return Color(red: 0.72, green: 0.18, blue: 0.18) }
        return .black.opacity(0.68)
    }

    private var balanceBackground: Color {
        if balance.isOwed { return Color(red: 0.90, green: 0.97, blue: 0.90) }
        if balance.owes { return Color(red: 0.99, green: 0.91, blue: 0.91) }
        return Color.white.opacity(0.74)
    }

    private func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

private struct TripPlannerExpenseComposerOverlay: View {
    let participants: [TripPlannerExpenseParticipant]
    let existingExpense: TripPlannerExpense?
    let onClose: () -> Void
    let onSaveExpense: (TripPlannerExpense) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var selectedPayerId: String = ""
    @State private var splitMode: TripPlannerExpenseSplitMode = .everyone
    @State private var selectedParticipantIds: Set<String> = []

    init(
        participants: [TripPlannerExpenseParticipant],
        existingExpense: TripPlannerExpense? = nil,
        onClose: @escaping () -> Void,
        onSaveExpense: @escaping (TripPlannerExpense) -> Void
    ) {
        self.participants = participants
        self.existingExpense = existingExpense
        self.onClose = onClose
        self.onSaveExpense = onSaveExpense
        _title = State(initialValue: existingExpense?.title ?? "")
        if let existingExpense {
            _amountText = State(initialValue: existingExpense.totalAmount == 0 ? "" : String(format: "%.2f", existingExpense.totalAmount))
            _selectedPayerId = State(initialValue: existingExpense.paidById)
            _splitMode = State(initialValue: existingExpense.splitMode)
            _selectedParticipantIds = State(initialValue: Set(existingExpense.participantIds))
        } else {
            _amountText = State(initialValue: "")
            _selectedPayerId = State(initialValue: "")
            _splitMode = State(initialValue: .everyone)
            _selectedParticipantIds = State(initialValue: [])
        }
    }

    private var canSaveExpense: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedAmount != nil
            && !selectedBeneficiaryIds.isEmpty
            && !selectedPayerId.isEmpty
    }

    private var parsedAmount: Double? {
        Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var selectedBeneficiaryIds: [String] {
        switch splitMode {
        case .everyone:
            return participants.map(\.id)
        case .selectedPeople:
            return Array(selectedParticipantIds)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(existingExpense == nil ? String(localized: "trip_planner.expenses.add_expense") : String(localized: "trip_planner.expenses.edit_expense"))
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.black)

                        Text("trip_planner.expenses.overlay_subtitle")
                            .font(.system(size: 15))
                            .foregroundStyle(.black.opacity(0.66))
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button(String(localized: "common.close")) {
                            onClose()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.65))

                        Button(existingExpense == nil ? String(localized: "common.add") : String(localized: "common.save")) {
                            saveExpense()
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .opacity(canSaveExpense ? 1 : 0.45)
                        .disabled(!canSaveExpense)
                    }
                }
                .padding(.bottom, 18)

                VStack(alignment: .leading, spacing: 14) {
                    TripPlannerTextInput(
                        title: String(localized: "trip_planner.expenses.expense_title"),
                        text: $title,
                        placeholder: String(localized: "trip_planner.expenses.expense_title_placeholder")
                    )

                    TripPlannerCurrencyInput(
                        title: String(localized: "trip_planner.expenses.amount_usd"),
                        text: $amountText,
                        placeholder: String(localized: "trip_planner.expenses.usd")
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("trip_planner.expenses.paid_by")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.72))

                        Picker(String(localized: "trip_planner.expenses.paid_by"), selection: $selectedPayerId) {
                            ForEach(participants) { participant in
                                Text(participant.name).tag(participant.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.84))
                        )

                    }

                    Picker(String(localized: "trip_planner.expenses.split"), selection: $splitMode) {
                        ForEach(TripPlannerExpenseSplitMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if splitMode == .selectedPeople {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("trip_planner.expenses.split_between")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.72))

                            TripPlannerChipGrid(
                                items: participants.map { participant in
                                    TripPlannerChipItem(
                                        id: participant.id,
                                        title: participant.name,
                                        isSelected: selectedParticipantIds.contains(participant.id)
                                    )
                                },
                                onTap: { item in
                                    if selectedParticipantIds.contains(item.id) {
                                        selectedParticipantIds.remove(item.id)
                                    } else {
                                        selectedParticipantIds.insert(item.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 620))
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
        .onAppear {
            if selectedPayerId.isEmpty {
                selectedPayerId = participants.first?.id ?? ""
            }
            if selectedParticipantIds.isEmpty {
                selectedParticipantIds = Set(participants.map(\.id))
            }
        }
    }

    private func saveExpense() {
        guard
            let amount = parsedAmount,
            let payer = participants.first(where: { $0.id == selectedPayerId })
        else {
            return
        }

        let beneficiaries = participants.filter { selectedBeneficiaryIds.contains($0.id) }
        let equalShare = beneficiaries.isEmpty ? 0 : amount / Double(beneficiaries.count)
        let shares = beneficiaries.compactMap { participant -> TripPlannerExpenseShare? in
            guard participant.id != payer.id else { return nil }
            return TripPlannerExpenseShare(
                participantId: participant.id,
                participantName: participant.name,
                participantUsername: participant.username,
                amountOwed: equalShare
            )
        }

        onSaveExpense(
            TripPlannerExpense(
                id: existingExpense?.id ?? UUID(),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                totalAmount: amount,
                paidById: payer.id,
                paidByName: payer.name,
                paidByUsername: payer.username,
                splitMode: splitMode,
                date: existingExpense?.date ?? Date(),
                participantIds: beneficiaries.map(\.id),
                participantNames: beneficiaries.map(\.name),
                shares: shares
            )
        )
    }
}

private struct TripPlannerExpenseRow: View {
    let expense: TripPlannerExpense
    let onEdit: (() -> Void)?
    let onUpdate: ((TripPlannerExpense) -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    Text(
                        String(
                            format: String(localized: "trip_planner.expenses.paid_by_format"),
                            locale: Locale.current,
                            currency(expense.totalAmount),
                            expense.paidByName
                        )
                    )
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.7))
                }

                Spacer()

                if let onEdit {
                    Button(String(localized: "common.edit")) {
                        onEdit()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.82)))
                }
            }

            if expense.shares.isEmpty {
                Text("trip_planner.expenses.no_one_owes")
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.62))
            } else {
                VStack(spacing: 8) {
                    ForEach(expense.shares) { share in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(
                                    String(
                                        format: String(localized: "trip_planner.expenses.owes_format"),
                                        locale: Locale.current,
                                        share.participantName,
                                        currency(share.amountOwed)
                                    )
                                )
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.black)

                                Spacer()

                                Text(share.isPaid ? String(localized: "trip_planner.expenses.paid") : String(localized: "trip_planner.expenses.not_paid"))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.7))
                            }

                            if let onUpdate {
                                HStack(spacing: 8) {
                                    Button(share.isPaid ? String(localized: "trip_planner.expenses.mark_unpaid") : String(localized: "trip_planner.expenses.mark_paid")) {
                                        onUpdate(updatedExpense(for: share, method: .manual, isPaid: !share.isPaid))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.82)))

                                    Button(String(localized: "trip_planner.expenses.venmo")) {
                                        onUpdate(updatedExpense(for: share, method: .venmo, isPaid: true))
                                        openVenmo(for: share)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.82)))

                                    Button(String(localized: "trip_planner.expenses.apple_pay")) {
                                        onUpdate(updatedExpense(for: share, method: .applePay, isPaid: true))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.82)))
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.7))
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }

    private func updatedExpense(
        for share: TripPlannerExpenseShare,
        method: TripPlannerExpensePaymentMethod,
        isPaid: Bool
    ) -> TripPlannerExpense {
        let updatedShares = expense.shares.map { currentShare in
            guard currentShare.id == share.id else { return currentShare }
            return TripPlannerExpenseShare(
                id: currentShare.id,
                participantId: currentShare.participantId,
                participantName: currentShare.participantName,
                participantUsername: currentShare.participantUsername,
                amountOwed: currentShare.amountOwed,
                isPaid: isPaid,
                paymentMethod: isPaid ? method : nil
            )
        }

        return TripPlannerExpense(
            id: expense.id,
            title: expense.title,
            totalAmount: expense.totalAmount,
            paidById: expense.paidById,
            paidByName: expense.paidByName,
            paidByUsername: expense.paidByUsername,
            splitMode: expense.splitMode,
            date: expense.date,
            participantIds: expense.participantIds,
            participantNames: expense.participantNames,
            shares: updatedShares
        )
    }

    private func openVenmo(for share: TripPlannerExpenseShare) {
        guard let recipient = expense.paidByUsername, !recipient.isEmpty else { return }
        let note = "\(expense.title) - \(share.participantName)"
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? note
        let amount = String(format: "%.2f", share.amountOwed)
        if let venmoURL = URL(string: "venmo://paycharge?txn=pay&recipients=\(recipient)&amount=\(amount)&note=\(encodedNote)") {
            openURL(venmoURL)
        }
    }

    private func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

private extension TripPlannerTrip {
    var countryChipItems: [(id: String, title: String)] {
        countryIds.map { id in
            (id: id, title: "\(id.flagEmoji) \(CountrySelectionFormatter.localizedName(for: id))")
        }
    }

    var availabilityParticipants: [TripPlannerAvailabilityParticipant] {
        [TripPlannerAvailabilityParticipant.you] + friends.map {
            TripPlannerAvailabilityParticipant(
                id: $0.id.uuidString,
                name: $0.displayName,
                username: $0.username,
                avatarURL: $0.avatarURL
            )
        }
    }
}

private struct TripPlannerAvailabilityParticipant: Identifiable, Hashable {
    let id: String
    let name: String
    let username: String?
    let avatarURL: String?

    static let you = TripPlannerAvailabilityParticipant(
        id: "self",
        name: String(localized: "trip_planner.you"),
        username: nil,
        avatarURL: nil
    )
}

private struct TripPlannerAvailabilityOverlap: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let exactParticipantCount: Int
    let totalParticipantCount: Int

    var isFullMatch: Bool {
        exactParticipantCount == totalParticipantCount
    }
}

private struct TripPlannerStatsSection: View {
    let countries: [Country]
    let startDate: Date?
    let endDate: Date?
    let tripDayPlans: [TripPlannerDayPlan]
    let weights: ScoreWeights
    let preferredMonth: Int
    let isGroupTrip: Bool
    let travelerCount: Int
    let passportLabel: String
    let groupLanguageScoresByCountry: [String: Int]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]

    private var selectedMonth: Int {
        guard let startDate else { return preferredMonth }
        return Calendar.current.component(.month, from: startDate)
    }

    private var scoredCountries: [Country] {
        countries.map {
            $0.applyingOverallScore(using: weights, selectedMonth: selectedMonth)
        }
    }

    private var affordabilityScores: [Int] {
        countries.compactMap(\.affordabilityScore)
    }

    private var dailySpendValues: [Double] {
        countries.compactMap(\.dailySpendTotalUsd)
    }

    private var countryByID: [String: Country] {
        Dictionary(uniqueKeysWithValues: countries.map { ($0.id, $0) })
    }

    private var normalizedDayPlans: [TripPlannerDayPlan] {
        TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: tripDayPlans,
            startDate: startDate,
            endDate: endDate,
            countries: countries.map { ($0.id, $0.name) }
        )
    }

    private var weightedCountryDays: [Country] {
        normalizedDayPlans.compactMap { plan in
            guard plan.kind == .country, let countryId = plan.countryId else { return nil }
            return countryByID[countryId]
        }
    }

    private var averageAffordability: Int? {
        guard !affordabilityScores.isEmpty else { return nil }
        return Int((Double(affordabilityScores.reduce(0, +)) / Double(affordabilityScores.count)).rounded())
    }

    private var averageDailySpend: Int? {
        let weightedSpend = weightedCountryDays.compactMap(\.dailySpendTotalUsd)
        if !weightedSpend.isEmpty {
            return Int((weightedSpend.reduce(0, +) / Double(weightedSpend.count)).rounded())
        }
        guard !dailySpendValues.isEmpty else { return nil }
        return Int((dailySpendValues.reduce(0, +) / Double(dailySpendValues.count)).rounded())
    }

    private var tripLengthDays: Int? {
        guard let startDate, let endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        return max(days + 1, 1)
    }

    private var estimatedTripCostPerPerson: Int? {
        let weightedSpend = weightedCountryDays.compactMap(\.dailySpendTotalUsd)
        if !weightedSpend.isEmpty {
            return Int(weightedSpend.reduce(0, +).rounded())
        }
        guard let averageDailySpend, let tripLengthDays else { return nil }
        return averageDailySpend * tripLengthDays
    }

    private var visaPrepCountries: [Country] {
        countries.filter {
            ["evisa", "visa_required", "entry_permit", "ban"].contains($0.visaType ?? "")
        }
    }

    private var easyEntryCountries: [Country] {
        countries.filter {
            ["own_passport", "freedom_of_movement", "visa_free", "voa"].contains($0.visaType ?? "")
        }
    }

    private var overstayRiskCountries: [Country] {
        guard let tripLengthDays else { return [] }
        return countries.filter { country in
            guard let allowedDays = country.visaAllowedDays else { return false }
            return tripLengthDays > allowedDays
        }
    }

    private var allCountriesVisaFreeForTrip: Bool {
        !countries.isEmpty && countries.allSatisfy { country in
            ["own_passport", "freedom_of_movement", "visa_free"].contains(country.visaType ?? "")
        } && overstayRiskCountries.isEmpty
    }

    private var allCountriesNeedNoAdvanceVisa: Bool {
        !countries.isEmpty && countries.allSatisfy { country in
            ["own_passport", "freedom_of_movement", "visa_free", "voa"].contains(country.visaType ?? "")
        } && overstayRiskCountries.isEmpty
    }

    private var averageOverallScore: Int? {
        average(of: scoredCountries.compactMap(\.score))
    }

    private var averageAdvisoryScore: Int? {
        average(of: countries.compactMap(\.advisoryScore))
    }

    private var averageSeasonalityScore: Int? {
        average(of: countries.compactMap { $0.resolvedSeasonalityScore(for: selectedMonth) })
    }

    private var categoryAverages: [TripPlannerScoreAverage] {
        [
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.overall"), subtitle: String(localized: "trip_planner.stats.category.overall_subtitle"), score: averageOverallScore),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.advisory"), subtitle: String(localized: "trip_planner.stats.category.advisory_subtitle"), score: averageAdvisoryScore),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.seasonality"), subtitle: monthSummaryText, score: averageSeasonalityScore),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.visa"), subtitle: String(localized: "trip_planner.stats.category.visa_subtitle"), score: average(of: countries.compactMap(\.visaEaseScore))),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.budget"), subtitle: String(localized: "trip_planner.stats.category.budget_subtitle"), score: averageAffordability),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.language"), subtitle: isGroupTrip ? String(localized: "trip_planner.stats.category.language_group_subtitle") : String(localized: "trip_planner.stats.category.language_solo_subtitle"), score: averageLanguageScore)
        ]
    }

    private var averageLanguageScore: Int? {
        let values = countries.compactMap { groupLanguageScoresByCountry[$0.id] }
        return average(of: values)
    }

    private var affectedTravelerCount: Int {
        Set(groupVisaNeeds.map(\.travelerId)).count
    }

    private var visibleVisaSummaries: [TripPlannerVisaSummary] {
        Array(visaSummaries.prefix(3))
    }

    private var hiddenVisaSummaryCount: Int {
        max(visaSummaries.count - visibleVisaSummaries.count, 0)
    }

    private var visaSummaries: [TripPlannerVisaSummary] {
        if isGroupTrip {
            var grouped: [String: TripPlannerVisaSummary] = [:]

            for need in groupVisaNeeds {
                if var existing = grouped[need.countryID] {
                    existing.add(need)
                    grouped[need.countryID] = existing
                } else {
                    grouped[need.countryID] = TripPlannerVisaSummary(need: need)
                }
            }

            return grouped.values.sorted { lhs, rhs in
                if lhs.exceedsAllowedStay != rhs.exceedsAllowedStay {
                    return lhs.exceedsAllowedStay && !rhs.exceedsAllowedStay
                }
                if lhs.travelerCount != rhs.travelerCount {
                    return lhs.travelerCount > rhs.travelerCount
                }
                return lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
            }
        }

        let riskByCountry = Dictionary(uniqueKeysWithValues: overstayRiskCountries.map { ($0.id, $0) })
        let prepOnlyCountries = visaPrepCountries.filter { riskByCountry[$0.id] == nil }
        let combined = overstayRiskCountries + prepOnlyCountries

        return combined.map { country in
            TripPlannerVisaSummary(
                countryID: country.id,
                countryName: country.name,
                countryFlag: country.flagEmoji,
                passportLabels: [country.visaPassportLabel ?? passportLabel],
                travelerNames: [],
                travelerCount: 0,
                allowedDays: country.visaAllowedDays,
                exceedsAllowedStay: overstayRiskCountries.contains(where: { $0.id == country.id }),
                visaType: country.visaType
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !countries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isGroupTrip ? String(localized: "trip_planner.stats.group_snapshot") : String(localized: "trip_planner.stats.trip_snapshot"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)

                    Text(snapshotSummary)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.68))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .top),
                            GridItem(.flexible(), spacing: 10, alignment: .top)
                        ],
                        spacing: 10
                    ) {
                        TripPlannerScoreHighlightCard(
                            title: String(localized: "trip_planner.stats.average_overall"),
                            subtitle: String(format: String(localized: "trip_planner.stats.across_stops_format"), locale: Locale.current, countries.count),
                            score: averageOverallScore
                        )

                        TripPlannerScoreHighlightCard(
                            title: String(localized: "trip_planner.stats.average_advisory"),
                            subtitle: String(localized: "trip_planner.stats.average_advisory_subtitle"),
                            score: averageAdvisoryScore
                        )

                        TripPlannerScoreHighlightCard(
                            title: String(localized: "trip_planner.stats.average_seasonality"),
                            subtitle: monthSummaryText,
                            score: averageSeasonalityScore
                        )
                    }
                }
            }

            if !categoryAverages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("trip_planner.stats.score_breakdown")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .top),
                            GridItem(.flexible(), spacing: 10, alignment: .top)
                        ],
                        spacing: 10
                    ) {
                        ForEach(categoryAverages) { metric in
                            TripPlannerCategoryAverageCard(metric: metric)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                TripPlannerStatPill(
                    title: String(localized: "trip_planner.stats.estimated_total_per_person"),
                    value: estimatedTripCostPerPerson.map { "$\($0) USD" } ?? String(localized: "trip_planner.stats.add_trip_dates"),
                    detail: "\(estimatedCostDetail) · USD"
                )

                TripPlannerStatPill(
                    title: String(localized: "trip_planner.stats.typical_daily_spend"),
                    value: averageDailySpend.map { "$\($0) USD" } ?? String(localized: "trip_planner.stats.na"),
                    detail: "\(dailySpendDetail) · USD"
                )
            }

            TripPlannerVisaSummaryCard(
                headline: visaSummaryValue,
                badges: visaBadges,
                summaries: visibleVisaSummaries,
                hiddenSummaryCount: hiddenVisaSummaryCount,
                tripLengthDays: tripLengthDays,
                passportLabel: passportLabel,
                isGroupTrip: isGroupTrip,
                allClearMessage: visaAllClearMessage
            )
        }
    }

    private var estimatedCostDetail: String {
        guard let tripLengthDays else {
            return String(localized: "trip_planner.stats.estimate_when_dates_set")
        }
        return String(format: String(localized: "trip_planner.stats.trip_length_estimate_format"), locale: Locale.current, tripLengthDays)
    }

    private var dailySpendDetail: String {
        if !weightedCountryDays.isEmpty {
            let travelDayCount = normalizedDayPlans.filter { $0.kind == .travel }.count
            if travelDayCount > 0 {
                return String(format: String(localized: "trip_planner.stats.weighted_excluding_travel_days_format"), locale: Locale.current, travelDayCount)
            }
            return String(localized: "trip_planner.stats.weighted_by_itinerary")
        }
        guard let averageAffordability else { return String(localized: "trip_planner.stats.across_selected_countries") }
        switch averageAffordability {
        case 80...:
            return String(localized: "trip_planner.stats.budget_friendly")
        case 60..<80:
            return String(localized: "trip_planner.stats.pretty_balanced")
        case 40..<60:
            return String(localized: "trip_planner.stats.mid_range_to_pricey")
        default:
            return String(localized: "trip_planner.stats.expensive")
        }
    }

    private var visaSummaryValue: String {
        if !overstayRiskCountries.isEmpty {
            return String(localized: "trip_planner.visa.plan_needed")
        }
        if isGroupTrip, affectedTravelerCount > 0 {
            return String(format: String(localized: "trip_planner.visa.traveler_prep_format"), locale: Locale.current, affectedTravelerCount)
        }
        if allCountriesVisaFreeForTrip {
            return String(localized: "trip_planner.visa.none_required")
        }
        if allCountriesNeedNoAdvanceVisa {
            return String(localized: "trip_planner.visa.no_advance_needed")
        }
        return String(format: String(localized: "trip_planner.visa.stops_to_prep_format"), locale: Locale.current, visaPrepCountries.count)
    }

    private var monthSummaryText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        return String(format: String(localized: "trip_planner.stats.month_timing_format"), locale: Locale.current, formatter.monthSymbols[selectedMonth - 1])
    }

    private var snapshotSummary: String {
        if isGroupTrip {
            return String(format: String(localized: "trip_planner.stats.group_snapshot_summary_format"), locale: Locale.current, travelerCount, countries.count)
        }

        return String(format: String(localized: "trip_planner.stats.selected_countries_summary_format"), locale: Locale.current, countries.count)
    }

    private func average(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private var overstayWarningText: String {
        let countriesText = overstayRiskCountries.map { "\($0.flagEmoji) \($0.name)" }.joined(separator: ", ")
        guard let tripLengthDays else {
            return String(localized: "trip_planner.visa.overstay_warning_generic")
        }
        return String(format: String(localized: "trip_planner.visa.overstay_warning_format"), locale: Locale.current, countriesText, tripLengthDays)
    }

    private var visaBadges: [String] {
        var badges: [String] = []

        if !countries.isEmpty {
            badges.append(String(format: String(localized: "trip_planner.visa.stop_count_format"), locale: Locale.current, countries.count))
        }

        if isGroupTrip {
            badges.append(String(format: String(localized: "trip_planner.visa.traveler_count_format"), locale: Locale.current, travelerCount))
            if !groupVisaNeeds.isEmpty {
                badges.append(String(format: String(localized: "trip_planner.visa.flag_count_format"), locale: Locale.current, groupVisaNeeds.count))
            }
        } else if !visaPrepCountries.isEmpty {
            badges.append(String(format: String(localized: "trip_planner.visa.stop_prep_count_format"), locale: Locale.current, visaPrepCountries.count))
        }

        if let tripLengthDays {
            badges.append(String(format: String(localized: "trip_planner.visa.day_count_format"), locale: Locale.current, tripLengthDays))
        }

        return badges
    }

    private var visaAllClearMessage: String? {
        if isGroupTrip, groupVisaNeeds.isEmpty {
            return String(localized: "trip_planner.visa.group_all_clear")
        }
        if allCountriesVisaFreeForTrip {
            return String(localized: "trip_planner.visa.every_stop_visa_free")
        }
        if allCountriesNeedNoAdvanceVisa {
            return String(localized: "trip_planner.visa.every_stop_no_advance")
        }
        return nil
    }
}

private struct TripPlannerTravelerVisaNeed: Identifiable, Hashable {
    let travelerId: UUID
    let travelerName: String
    let countryID: String
    let countryName: String
    let countryFlag: String
    let passportLabel: String
    let visaType: String
    let allowedDays: Int?
    let exceedsAllowedStay: Bool

    var id: String {
        "\(travelerId.uuidString)::\(countryID)"
    }

    func summaryText(tripLengthDays: Int?) -> String {
        if exceedsAllowedStay, let tripLengthDays, let allowedDays {
            return String(format: String(localized: "trip_planner.visa.traveler_overstay_summary_format"), locale: Locale.current, travelerName, countryFlag, countryName, passportLabel, allowedDays, tripLengthDays)
        }

        return String(format: String(localized: "trip_planner.visa.traveler_prep_summary_format"), locale: Locale.current, travelerName, countryFlag, countryName, passportLabel)
    }
}

private struct TripPlannerVisaSummary: Identifiable, Hashable {
    let countryID: String
    let countryName: String
    let countryFlag: String
    var passportLabels: [String]
    var travelerNames: [String]
    var travelerCount: Int
    let allowedDays: Int?
    var exceedsAllowedStay: Bool
    let visaType: String?

    init(
        countryID: String,
        countryName: String,
        countryFlag: String,
        passportLabels: [String],
        travelerNames: [String],
        travelerCount: Int,
        allowedDays: Int?,
        exceedsAllowedStay: Bool,
        visaType: String?
    ) {
        self.countryID = countryID
        self.countryName = countryName
        self.countryFlag = countryFlag
        self.passportLabels = passportLabels
        self.travelerNames = travelerNames
        self.travelerCount = travelerCount
        self.allowedDays = allowedDays
        self.exceedsAllowedStay = exceedsAllowedStay
        self.visaType = visaType
    }

    init(need: TripPlannerTravelerVisaNeed) {
        self.init(
            countryID: need.countryID,
            countryName: need.countryName,
            countryFlag: need.countryFlag,
            passportLabels: [need.passportLabel],
            travelerNames: [need.travelerName],
            travelerCount: 1,
            allowedDays: need.allowedDays,
            exceedsAllowedStay: need.exceedsAllowedStay,
            visaType: need.visaType
        )
    }

    var id: String { countryID }

    mutating func add(_ need: TripPlannerTravelerVisaNeed) {
        travelerCount += 1
        exceedsAllowedStay = exceedsAllowedStay || need.exceedsAllowedStay
        travelerNames = Array(NSOrderedSet(array: travelerNames + [need.travelerName])) as? [String] ?? travelerNames
        passportLabels = Array(NSOrderedSet(array: passportLabels + [need.passportLabel])) as? [String] ?? passportLabels
    }
}

private struct TripPlannerVisaSummaryCard: View {
    let headline: String
    let badges: [String]
    let summaries: [TripPlannerVisaSummary]
    let hiddenSummaryCount: Int
    let tripLengthDays: Int?
    let passportLabel: String
    let isGroupTrip: Bool
    let allClearMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("trip_planner.visa.title")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.58))

                    Text(headline)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                }
            }

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            TripPlannerBadge(text: badge)
                        }
                    }
                }
            }

            if let allClearMessage, summaries.isEmpty {
                TripPlannerInfoCard(
                    text: allClearMessage,
                    systemImage: "checkmark.seal.fill"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(summaries) { summary in
                        TripPlannerVisaCountryRow(
                            summary: summary,
                            tripLengthDays: tripLengthDays,
                            passportLabel: passportLabel,
                            isGroupTrip: isGroupTrip
                        )
                    }
                }

                if hiddenSummaryCount > 0 {
                    TripPlannerInfoCard(
                        text: String(format: String(localized: "trip_planner.visa.hidden_summary_format"), locale: Locale.current, hiddenSummaryCount),
                        systemImage: "ellipsis.circle.fill"
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
    }

    private var iconName: String {
        summaries.contains(where: \.exceedsAllowedStay) ? "exclamationmark.triangle.fill" : "globe.badge.chevron.backward"
    }

    private var iconBackgroundColor: Color {
        summaries.contains(where: \.exceedsAllowedStay)
            ? Color(red: 0.94, green: 0.84, blue: 0.73)
            : Color.black.opacity(0.08)
    }
}

private struct TripPlannerVisaCountryRow: View {
    let summary: TripPlannerVisaSummary
    let tripLengthDays: Int?
    let passportLabel: String
    let isGroupTrip: Bool

    private var countryDestination: Country {
        Country(
            iso2: summary.countryID,
            name: summary.countryName,
            score: nil
        )
    }

    private var travelerPreview: String {
        let names = summary.travelerNames
        guard !names.isEmpty else { return "" }
        return ListFormatter.localizedString(byJoining: names)
    }

    private var statusText: String {
        if summary.exceedsAllowedStay, let tripLengthDays, let allowedDays = summary.allowedDays {
            if isGroupTrip, summary.travelerCount > 0 {
                return String(format: String(localized: "trip_planner.visa.group_overstay_status_format"), locale: Locale.current, travelerPreview, allowedDays, tripLengthDays)
            }
            return String(format: String(localized: "trip_planner.visa.solo_overstay_status_format"), locale: Locale.current, allowedDays, tripLengthDays)
        }

        if isGroupTrip, summary.travelerCount > 0 {
            if summary.travelerCount == 1 {
                return String(format: String(localized: "trip_planner.visa.one_traveler_needs_visa_format"), locale: Locale.current, travelerPreview)
            }
            return String(format: String(localized: "trip_planner.visa.multiple_travelers_need_visa_format"), locale: Locale.current, travelerPreview)
        }

        let label = summary.passportLabels.first ?? passportLabel
        let country = Country(iso2: summary.countryID, name: summary.countryName, score: nil).applyingVisa(
            visaEaseScore: nil,
            visaType: summary.visaType,
            visaAllowedDays: summary.allowedDays,
            visaFeeUsd: nil,
            visaNotes: nil,
            visaSourceUrl: nil,
            visaPassportCode: nil,
            visaPassportLabel: label,
            visaRecommendedPassportLabel: nil
        )
        return CountryVisaHelpers.headline(for: country, passportLabel: label)
    }

    var body: some View {
        NavigationLink {
            CountryDetailView(country: countryDestination)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(summary.countryFlag) \(CountrySelectionFormatter.localizedName(for: summary.countryID))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.78))
                }

                Spacer(minLength: 0)

                Image(systemName: summary.exceedsAllowedStay ? "exclamationmark.triangle.fill" : "chevron.forward.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.42))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95).opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TripPlannerScoreHighlightCard: View {
    let title: String
    let subtitle: String
    let score: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.62))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let score {
                ScorePill(score: score)
                    .fixedSize(horizontal: true, vertical: true)
            } else {
                Text("trip_planner.stats.na")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: true, vertical: true)
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
    }
}

private struct TripPlannerScoreAverage: Identifiable {
    let title: String
    let subtitle: String
    let score: Int?

    var id: String { title }
}

private struct TripPlannerCategoryAverageCard: View {
    let metric: TripPlannerScoreAverage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            if let score = metric.score {
                ScorePill(score: score)
                    .fixedSize(horizontal: true, vertical: true)
            } else {
                Text("trip_planner.stats.na")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black.opacity(0.58))
                    .fixedSize(horizontal: true, vertical: true)
            }

            Text(metric.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.76))
        )
    }
}

private struct TripPlannerCountryLanguageProfile: Decodable {
    let countryISO2: String
    let languages: [TripPlannerCountryLanguageCoverage]

    enum CodingKeys: String, CodingKey {
        case countryISO2 = "country_iso2"
        case languages
    }
}

private struct TripPlannerCountryLanguageCoverage: Decodable, Hashable {
    let code: String
    let type: String
    let coverage: Double
}

private actor TripPlannerCountryLanguageProfileStore {
    static let shared = TripPlannerCountryLanguageProfileStore()

    private var cache: [String: TripPlannerCountryLanguageProfile] = [:]
    private var missingISO2: Set<String> = []

    func profile(for iso2: String) async throws -> TripPlannerCountryLanguageProfile? {
        let normalizedISO2 = iso2.uppercased()

        if let cached = cache[normalizedISO2] {
            return cached
        }

        if missingISO2.contains(normalizedISO2) {
            return nil
        }

        let response: PostgrestResponse<[TripPlannerCountryLanguageProfile]> = try await SupabaseManager.shared.client
            .from("country_language_profiles")
            .select("country_iso2,languages")
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
}

private enum TripPlannerGroupLanguageCompatibilityScorer {
    static func score(
        travelerLanguages: [Profile.LanguageJSON],
        countryProfile: TripPlannerCountryLanguageProfile
    ) -> Int? {
        guard !countryProfile.languages.isEmpty else { return 0 }

        let spokenCodes = Set(
            travelerLanguages.map { language in
                LanguageRepository.shared.canonicalLanguageCode(for: language.code)
                    ?? language.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        guard !spokenCodes.isEmpty else { return nil }

        let countryCodes = Set(
            countryProfile.languages.map { coverage in
                LanguageRepository.shared.canonicalLanguageCode(for: coverage.code)
                    ?? coverage.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        return spokenCodes.isDisjoint(with: countryCodes) ? 0 : 100
    }
}

private struct TripPlannerStatPill: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.62))

            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.black)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct TripPlannerAvailabilitySection: View {
    let trip: TripPlannerTrip

    private var overlaps: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip)
    }

    private var exactProposalCount: Int {
        trip.availability.filter { $0.kind == .exactDates }.count
    }

    private var monthProposalCount: Int {
        trip.availability.filter { $0.kind == .flexibleMonth }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if trip.availability.isEmpty {
                TripPlannerInfoCard(
                    text: trip.isGroupTrip
                        ? String(localized: "trip_planner.availability.summary_empty_group")
                        : String(localized: "trip_planner.availability.summary_empty_solo")
                    ,
                    systemImage: "calendar.badge.plus"
                )
            } else {
                TripPlannerAvailabilityCalendarBoard(trip: trip)

                VStack(alignment: .leading, spacing: 8) {
                    Text("trip_planner.availability.trip_route_title")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    TripPlannerItineraryPreview(trip: trip)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("trip_planner.availability.best_shared_windows")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    if overlaps.isEmpty {
                        TripPlannerInfoCard(
                            text: String(localized: "trip_planner.availability.summary_no_shared_window"),
                            systemImage: "sparkles"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(overlaps.prefix(3)) { overlap in
                                TripPlannerOverlapCard(overlap: overlap)
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TripPlannerBadge(text: String(
                        format: String(localized: "trip_planner.availability.date_range_count"),
                        locale: Locale.current,
                        exactProposalCount
                    ))
                    if monthProposalCount > 0 {
                        TripPlannerBadge(text: String(
                            format: String(localized: "trip_planner.availability.flexible_month_count"),
                            locale: Locale.current,
                            monthProposalCount
                        ))
                    }
                }
            }
        }
    }
}

private struct TripPlannerAvailabilityCalendarBoard: View {
    let trip: TripPlannerTrip
    @State private var selectedMonthPage: Date

    init(trip: TripPlannerTrip) {
        self.trip = trip
        _selectedMonthPage = State(
            initialValue: TripPlannerAvailabilityCalculator.primaryDisplayMonth(for: trip)
                ?? TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
        )
    }

    private var proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])] {
        trip.availabilityParticipants.compactMap { participant in
            let proposals = trip.availability.filter { $0.participantId == participant.id }
            guard !proposals.isEmpty else { return nil }
            return (participant, proposals)
        }
    }

    private var monthsToDisplay: [Date] {
        let calendar = Calendar.current
        let allDates = trip.availability.flatMap { [$0.startDate, $0.endDate] } + [trip.startDate, trip.endDate].compactMap { $0 }

        guard
            let minDate = allDates.min(),
            let maxDate = allDates.max()
        else {
            if let primary = TripPlannerAvailabilityCalculator.primaryDisplayMonth(for: trip) {
                return [primary]
            }
            return []
        }

        let startMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: minDate)
        let endMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: maxDate)

        var months: [Date] = []
        var current = startMonth

        while current <= endMonth {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        return months
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("trip_planner.availability.calendar_view")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(proposalsByParticipant.enumerated()), id: \.1.0.id) { index, entry in
                        let participant = entry.0

                        HStack(spacing: 8) {
                            Circle()
                                .fill(TripPlannerAvailabilityTheme.color(for: participant.id, index: index))
                                .frame(width: 10, height: 10)

                            Text(participant.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.82))
                        )
                    }

                    if trip.startDate != nil, trip.endDate != nil {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.black)
                                .frame(width: 10, height: 10)

                            Text("trip_planner.availability.trip_dates")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.82))
                        )
                    }
                }
            }

            if !monthsToDisplay.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("trip_planner.availability.swipe_months")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.58))

                    TabView(selection: $selectedMonthPage) {
                        ForEach(monthsToDisplay, id: \.self) { month in
                            TripPlannerAvailabilityMonthCard(
                                month: month,
                                trip: trip,
                                proposalsByParticipant: proposalsByParticipant
                            )
                            .tag(month)
                            .padding(.bottom, 8)
                        }
                    }
                    .frame(height: 390)
                    .tabViewStyle(.page(indexDisplayMode: monthsToDisplay.count > 1 ? .automatic : .never))
                }
            }
        }
    }
}

private struct TripPlannerAvailabilityMonthCard: View {
    let month: Date
    let trip: TripPlannerTrip
    let proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var daySlots: [Date?] {
        TripPlannerAvailabilityCalculator.daySlots(for: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TripPlannerAvailabilityCalculator.monthTitle(for: month))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TripPlannerAvailabilityCalculator.weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                    if let day {
                        TripPlannerAvailabilityDayCell(
                            date: day,
                            month: month,
                            trip: trip,
                            proposalsByParticipant: proposalsByParticipant
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

private struct TripPlannerAvailabilityDayCell: View {
    let date: Date
    let month: Date
    let trip: TripPlannerTrip
    let proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])]

    private var inMonth: Bool {
        Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
    }

    private var availableColors: [Color] {
        proposalsByParticipant.enumerated().compactMap { index, entry in
            let hasAvailability = entry.1.contains { proposal in
                TripPlannerAvailabilityCalculator.includes(date: date, in: proposal)
            }
            guard hasAvailability else { return nil }
            return TripPlannerAvailabilityTheme.color(for: entry.0.id, index: index)
        }
    }

    private var isConfirmedTripDay: Bool {
        TripPlannerAvailabilityCalculator.includes(date: date, start: trip.startDate, end: trip.endDate)
    }

    private var isSharedDay: Bool {
        !availableColors.isEmpty && availableColors.count == proposalsByParticipant.count
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textColor)

            HStack(spacing: 2) {
                ForEach(Array(availableColors.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .opacity(inMonth ? 1 : 0.35)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isConfirmedTripDay {
            return .black
        }
        if isSharedDay {
            return Color(red: 0.91, green: 0.84, blue: 0.64)
        }
        if !availableColors.isEmpty {
            return Color.white.opacity(0.92)
        }
        return Color.black.opacity(0.05)
    }

    private var borderColor: Color {
        if isConfirmedTripDay {
            return .black
        }
        if isSharedDay {
            return Color.black.opacity(0.22)
        }
        if !availableColors.isEmpty {
            return Color.black.opacity(0.1)
        }
        return .clear
    }

    private var textColor: Color {
        isConfirmedTripDay ? .white : .black
    }
}

private struct TripPlannerProposalChip: View {
    let proposal: TripPlannerAvailabilityProposal
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(TripPlannerAvailabilityCalculator.label(for: proposal))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.88))
        )
    }
}

private struct TripPlannerOverlapCard: View {
    let overlap: TripPlannerAvailabilityOverlap

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: overlap.isFullMatch ? "checkmark.seal.fill" : "calendar.badge.clock")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 4) {
                Text(TripPlannerDateFormatter.rangeText(start: overlap.startDate, end: overlap.endDate) ?? String(localized: "trip_planner.availability.shared_window"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)

                Text(overlap.isFullMatch
                    ? String(localized: "trip_planner.availability.overlap_full_match")
                    : String(
                        format: String(localized: "trip_planner.availability.overlap_partial_match"),
                        locale: Locale.current,
                        overlap.exactParticipantCount,
                        overlap.totalParticipantCount
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.68))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct TripPlannerSavedTripCard: View {
    let trip: TripPlannerTrip
    let onDelete: () -> Void
    let onAddToCalendar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.black)

                    Text(trip.isGroupTrip ? String(localized: "trip_planner.detail.group_trip") : String(localized: "trip_planner.detail.solo_trip"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.62))
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }

            if let rangeText = TripPlannerDateFormatter.rangeText(start: trip.startDate, end: trip.endDate) {
                Label(rangeText, systemImage: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
            }

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.74))
            }

            if !trip.friendNames.isEmpty {
                Text(String(
                    format: String(localized: "trip_planner.saved_trip.with_format"),
                    locale: Locale.current,
                    trip.friendNames.joined(separator: ", ")
                ))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
            }

            TripPlannerChipGrid(
                items: trip.countryChipItems.map {
                    TripPlannerChipItem(id: $0.id, title: $0.title, isSelected: false)
                },
                onTap: { _ in }
            )

            if trip.startDate != nil, trip.endDate != nil {
                Button {
                    onAddToCalendar()
                } label: {
                    Label("trip_planner.actions.add_to_calendar", systemImage: "calendar.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.85))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerEmptyStateCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 32))
                .foregroundStyle(.black.opacity(0.82))

            Text("trip_planner.empty.title")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)

            Text("trip_planner.empty.subtitle")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.72))

            Text("trip_planner.empty.cta")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                )
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerEditableSectionCard<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.68))
                }

                Spacer()
                accessory
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: subtitle.isEmpty ? 0 : 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.68))
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerCountryList: View {
    let countries: [Country]
    let selectedIds: Set<String>
    let bucketIds: Set<String>
    let sharedIds: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(countries) { country in
                Button {
                    onTap(country.id)
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flagEmoji)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(country.localizedDisplayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)

                            HStack(spacing: 6) {
                                if bucketIds.contains(country.id) {
                                    TripPlannerBadge(text: String(localized: "planning.list_kind.bucket.short"))
                                }

                                if sharedIds.contains(country.id) {
                                    TripPlannerBadge(text: String(localized: "trip_planner.shared"))
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: selectedIds.contains(country.id) ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(selectedIds.contains(country.id) ? 0.9 : 0.72))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerFriendRow: View {
    let profile: Profile
    let isSelected: Bool
    let displayName: String
    var mutualBucketCount: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            TripPlannerAvatarView(
                name: displayName,
                username: profile.username,
                avatarURL: profile.avatarUrl,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let mutualBucketCount {
                        Text(String(format: String(localized: "trip_planner.friends.mutual_count_format"), locale: Locale.current, mutualBucketCount))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black.opacity(0.62))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.07))
                            )
                    }
                }

                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.62))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.9 : 0.72))
        )
    }
}

private struct TripPlannerSelectedFriendCard: View {
    let friend: TripPlannerFriendSnapshot

    var body: some View {
        HStack(spacing: 12) {
            TripPlannerAvatarView(
                name: friend.displayName,
                username: friend.username,
                avatarURL: friend.avatarURL,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)

                Text("@\(friend.username)")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.62))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct TripPlannerAvatarView: View {
    let name: String
    let username: String
    let avatarURL: String?
    let size: CGFloat

    private var initials: String {
        let source = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? username : name
        let parts = source.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Group {
            if let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.08))

            Text(initials)
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
        }
    }
}

private struct TripPlannerProfileDestinationView: View {
    let userId: UUID

    @StateObject private var socialNav = SocialNavigationController()

    var body: some View {
        ProfileView(userId: userId, showsBackButton: true)
            .environmentObject(socialNav)
            .navigationDestination(for: SocialRoute.self) { route in
                socialDestination(route)
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

private struct TripPlannerFriendPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let friends: [Profile]
    let selectedIds: Set<UUID>
    let displayName: (Profile) -> String
    let mutualBucketCount: (UUID) -> Int
    let onToggle: (UUID) -> Void

    @State private var searchText = ""

    private var filteredFriends: [Profile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return friends }

        return friends.filter { friend in
            let name = displayName(friend)
            return name.localizedCaseInsensitiveContains(trimmed)
                || friend.username.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripPlannerTextInput(
                    title: String(localized: "trip_planner.friends.search_title"),
                    text: $searchText,
                    placeholder: String(localized: "trip_planner.friends.search_placeholder")
                )

                LazyVStack(spacing: 10) {
                    ForEach(filteredFriends) { friend in
                        Button {
                            onToggle(friend.id)
                        } label: {
                            TripPlannerFriendRow(
                                profile: friend,
                                isSelected: selectedIds.contains(friend.id),
                                displayName: displayName(friend),
                                mutualBucketCount: mutualBucketCount(friend.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .navigationTitle(String(localized: "trip_planner.travel_friends"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.done")) {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
    }
}

private struct TripPlannerCountryPickerSection: Identifiable {
    let title: String
    let countries: [Country]

    var id: String { title }
}

private struct TripPlannerCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let sections: [TripPlannerCountryPickerSection]
    let selectedIds: Set<String>
    let bucketIds: Set<String>
    let sharedIds: Set<String>
    let onTap: (String) -> Void

    @State private var searchText = ""

    private var filteredSections: [TripPlannerCountryPickerSection] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sections }

        return sections.compactMap { section in
            let filteredCountries = section.countries.filter { country in
                country.localizedSearchableNames.contains {
                    $0.localizedCaseInsensitiveContains(trimmed)
                }
                    || country.id.localizedCaseInsensitiveContains(trimmed)
            }
            guard !filteredCountries.isEmpty else { return nil }
            return TripPlannerCountryPickerSection(title: section.title, countries: filteredCountries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripPlannerTextInput(
                    title: String(localized: "trip_planner.countries.search_title"),
                    text: $searchText,
                    placeholder: String(localized: "trip_planner.countries.search_placeholder")
                )

                ForEach(filteredSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)

                        TripPlannerCountryList(
                            countries: section.countries,
                            selectedIds: selectedIds,
                            bucketIds: bucketIds,
                            sharedIds: sharedIds,
                            onTap: onTap
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.done")) {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
    }
}

private struct TripPlannerChipItem: Identifiable, Hashable {
    let id: String
    let title: String
    let isSelected: Bool
}

private struct TripPlannerCountryNavigationGrid: View {
    let countries: [Country]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(countries) { country in
                NavigationLink {
                    CountryDetailView(country: country)
                } label: {
                    HStack(spacing: 8) {
                        Text("\(country.flagEmoji) \(country.localizedDisplayName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerChipGrid: View {
    let items: [TripPlannerChipItem]
    let onTap: (TripPlannerChipItem) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        if item.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(item.isSelected ? 0.95 : 0.78))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(item.isSelected ? Color.black.opacity(0.22) : Color.clear, lineWidth: 1.4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black.opacity(0.72))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.08))
            )
    }
}

private struct TripPlannerInfoCard: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.74))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
    }
}

private struct TripPlannerTextInput: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.72))

            Group {
                if axis == .vertical {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(4...8)
                } else {
                    TextField(placeholder, text: $text)
                        .lineLimit(1)
                }
            }
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .foregroundStyle(.black)
        }
    }
}

private struct TripPlannerCurrencyInput: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.72))

            HStack(spacing: 10) {
                Text("$")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)

                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
        }
    }
}

private enum TripPlannerAvailabilityTheme {
    private static let palette: [Color] = [
        Color(red: 0.82, green: 0.46, blue: 0.36),
        Color(red: 0.30, green: 0.56, blue: 0.78),
        Color(red: 0.52, green: 0.66, blue: 0.34),
        Color(red: 0.74, green: 0.56, blue: 0.78),
        Color(red: 0.88, green: 0.68, blue: 0.30),
        Color(red: 0.31, green: 0.63, blue: 0.57)
    ]

    static func color(for participantId: String, index: Int) -> Color {
        let seed = abs(participantId.hashValue + index)
        return palette[seed % palette.count]
    }
}

private enum TripPlannerAvailabilityCalculator {
    static func overlaps(for trip: TripPlannerTrip, proposals: [TripPlannerAvailabilityProposal]? = nil) -> [TripPlannerAvailabilityOverlap] {
        let proposals = proposals ?? trip.availability
        let participants = trip.availabilityParticipants
        guard participants.count > 1 else { return [] }

        let grouped = participants.map { participant in
            proposals
                .filter { $0.participantId == participant.id }
                .map { interval(for: $0) }
        }

        guard grouped.allSatisfy({ !$0.isEmpty }) else { return [] }

        let normalized = grouped.map(merge(_:))
        let exactCounts = participants.reduce(into: [String: Int]()) { partial, participant in
            partial[participant.id] = proposals.filter {
                $0.participantId == participant.id && $0.kind == .exactDates
            }.count
        }

        var matches: [TripPlannerAvailabilityOverlap] = []
        let first = normalized[0]
        for baseInterval in first {
            var intersections = [baseInterval]
            for other in normalized.dropFirst() {
                intersections = intersections.flatMap { current in
                    other.compactMap { candidate in
                        intersect(current, candidate)
                    }
                }
                if intersections.isEmpty { break }
            }

            for result in intersections {
                let exactCount = participants.reduce(into: 0) { count, participant in
                    let hasExactMatch = proposals.contains { proposal in
                        proposal.participantId == participant.id
                            && proposal.kind == .exactDates
                            && interval(for: proposal).intersects(result)
                    }
                    if hasExactMatch {
                        count += 1
                    } else if exactCounts[participant.id] == 0 {
                        count += 1
                    }
                }

                matches.append(
                    TripPlannerAvailabilityOverlap(
                        startDate: result.start,
                        endDate: result.end,
                        exactParticipantCount: exactCount,
                        totalParticipantCount: participants.count
                    )
                )
            }
        }

        return merge(matches)
            .sorted {
                if $0.exactParticipantCount == $1.exactParticipantCount {
                    return $0.startDate < $1.startDate
                }
                return $0.exactParticipantCount > $1.exactParticipantCount
            }
    }

    static func visibleMonths(for trip: TripPlannerTrip) -> [Date] {
        let calendar = Calendar.current
        let dates = trip.availability.flatMap { [$0.startDate, $0.endDate] } + [trip.startDate, trip.endDate].compactMap { $0 }
        let anchor = dates.min() ?? Date()
        let start = startOfMonth(for: anchor)
        return (0..<6).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    static func primaryDisplayMonth(for trip: TripPlannerTrip) -> Date? {
        if let overlap = overlaps(for: trip).first {
            return startOfMonth(for: overlap.startDate)
        }

        if let startDate = trip.startDate {
            return startOfMonth(for: startDate)
        }

        if let proposal = trip.availability.sorted(by: { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.startDate < rhs.startDate
            }
            return lhs.kind == .exactDates
        }).first {
            return startOfMonth(for: proposal.startDate)
        }

        return nil
    }

    static func label(for proposal: TripPlannerAvailabilityProposal) -> String {
        switch proposal.kind {
        case .exactDates:
            return String(format: String(localized: "trip_planner.availability.label_exact_format"), locale: Locale.current, TripPlannerDateFormatter.rangeText(start: proposal.startDate, end: proposal.endDate) ?? String(localized: "trip_planner.availability.label_dates"))
        case .flexibleMonth:
            return String(format: String(localized: "trip_planner.availability.label_flexible_format"), locale: Locale.current, monthTitle(for: proposal.startDate))
        }
    }

    static func monthLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: month)
    }

    static func monthTitle(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: month)
    }

    static func weekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        return formatter.shortStandaloneWeekdaySymbols
    }

    static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func endOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = startOfMonth(for: date)
        return calendar.date(byAdding: .month, value: 1, to: start) ?? start
    }

    static func intersectsMonth(_ proposal: TripPlannerAvailabilityProposal, month: Date) -> Bool {
        interval(for: proposal).intersects(DateInterval(start: startOfMonth(for: month), end: endOfMonth(for: month)))
    }

    static func rangeIntersectsMonth(start: Date?, end: Date?, month: Date) -> Bool {
        guard let start, let end else { return false }
        return DateInterval(start: start, end: Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end).intersects(
            DateInterval(start: startOfMonth(for: month), end: endOfMonth(for: month))
        )
    }

    static func includes(date: Date, in proposal: TripPlannerAvailabilityProposal) -> Bool {
        includes(date: date, start: proposal.startDate, end: proposal.endDate)
    }

    static func includes(date: Date, start: Date?, end: Date?) -> Bool {
        guard let start, let end else { return false }
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        return normalizedDate >= normalizedStart && normalizedDate <= normalizedEnd
    }

    static func daySlots(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(for: month)
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7

        var slots: [Date?] = Array(repeating: nil, count: leadingPadding)
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                slots.append(date)
            }
        }

        while slots.count % 7 != 0 {
            slots.append(nil)
        }

        return slots
    }

    private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var result: [DateInterval] = []

        for interval in sorted {
            guard let last = result.last else {
                result.append(interval)
                continue
            }

            if last.intersects(interval) || Calendar.current.isDate(last.end, inSameDayAs: interval.start) {
                let merged = DateInterval(start: last.start, end: max(last.end, interval.end))
                result[result.count - 1] = merged
            } else {
                result.append(interval)
            }
        }

        return result
    }

    private static func interval(for proposal: TripPlannerAvailabilityProposal) -> DateInterval {
        DateInterval(
            start: proposal.startDate,
            end: Calendar.current.date(byAdding: .day, value: 1, to: proposal.endDate) ?? proposal.endDate
        )
    }

    private static func intersect(_ lhs: DateInterval, _ rhs: DateInterval) -> DateInterval? {
        let start = max(lhs.start, rhs.start)
        let end = min(lhs.end, rhs.end)
        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func merge(_ overlaps: [TripPlannerAvailabilityOverlap]) -> [TripPlannerAvailabilityOverlap] {
        var result: [TripPlannerAvailabilityOverlap] = []

        for overlap in overlaps.sorted(by: { $0.startDate < $1.startDate }) {
            if let last = result.last,
               Calendar.current.isDate(last.startDate, inSameDayAs: overlap.startDate),
               Calendar.current.isDate(last.endDate, inSameDayAs: overlap.endDate),
               last.exactParticipantCount == overlap.exactParticipantCount {
                continue
            }
            result.append(overlap)
        }

        return result
    }
}

private enum TripPlannerDateFormatter {
    static func rangeText(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        return AppDateFormatting.dateRangeString(start: start, end: end)
    }
}

private struct TripPlannerCalendarSheet: UIViewControllerRepresentable {
    let draft: TripPlannerCalendarDraft

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = draft.store
        controller.event = draft.event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
        }
    }
}
