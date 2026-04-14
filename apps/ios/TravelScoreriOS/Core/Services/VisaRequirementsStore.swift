import Foundation
import Combine

private struct VisaSyncRunRow: Decodable {
    let version: Int
    let passportFromRaw: String?
    let passportFromISO2: String?

    enum CodingKeys: String, CodingKey {
        case version
        case passportFromRaw = "passport_from_raw"
        case passportFromISO2 = "passport_from_iso2"
    }
}

private struct VisaRequirementRow: Codable {
    let passportFromRaw: String
    let passportFromNorm: String
    let passportFromISO2: String
    let visitorToRaw: String
    let visitorToNorm: String
    let parentNorm: String?
    let isSpecialSubregion: Bool?
    let aliasesNorm: [String]?
    let requirement: String?
    let allowedStay: String?
    let notes: String?
    let version: Int
    let source: String?
    let sourceURL: String?
    let lastVerifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case passportFromRaw = "passport_from_raw"
        case passportFromNorm = "passport_from_norm"
        case passportFromISO2 = "passport_from_iso2"
        case visitorToRaw = "visitor_to_raw"
        case visitorToNorm = "visitor_to_norm"
        case parentNorm = "parent_norm"
        case isSpecialSubregion = "is_special_subregion"
        case aliasesNorm = "aliases_norm"
        case requirement
        case allowedStay = "allowed_stay"
        case notes
        case version
        case source
        case sourceURL = "source_url"
        case lastVerifiedAt = "last_verified_at"
    }
}

private struct CachedVisaDataset: Codable {
    let passportCountryCode: String
    let version: Int
    let rows: [VisaRequirementRow]
    let savedAt: Date
}

private struct VisaSnapshot {
    let passportCountryCode: String
    let passportLabel: String
    let visaType: String?
    let visaEaseScore: Int?
    let visaAllowedDays: Int?
    let visaFeeUsd: Double?
    let visaNotes: String?
    let visaSourceUrl: URL?
}

private struct HydratedVisaResult {
    let snapshot: VisaSnapshot
    let passportCode: String?
    let passportLabel: String?
    let recommendedPassportLabel: String?
}

private enum VisaRowMatcher {
    private static var countryLabelLocale: Locale { AppDisplayLocale.current }

    static func normalize(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\[\\d+\\]", with: " ", options: .regularExpression)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = normalized.split(separator: " ").map(String.init)
        var collapsed: [String] = []

        for token in tokens {
            if
                token.count == 1,
                let last = collapsed.last,
                last.count == 1
            {
                collapsed[collapsed.count - 1] = last + token
            } else {
                collapsed.append(token)
            }
        }

        return collapsed.joined(separator: " ")
    }

    static func aliases(forISO2 iso2: String) -> [String] {
        switch iso2.uppercased() {
        case "AX": return ["aland islands", "aland"]
        case "BL": return ["saint barthelemy", "st barthelemy"]
        case "BS": return ["bahamas", "the bahamas"]
        case "CI": return ["cote d ivoire", "cote ivoire", "ivory coast"]
        case "CW": return ["curacao", "curaçao"]
        case "GM": return ["gambia", "the gambia"]
        case "KR": return ["south korea", "republic of korea", "korea south"]
        case "LA": return ["laos", "lao", "lao peoples democratic republic"]
        case "MF": return ["saint martin", "st martin", "saint martin french part"]
        case "MM": return ["myanmar", "burma"]
        case "PS": return ["palestine", "palestinian territories", "palestinian territory"]
        case "RE": return ["reunion", "réunion"]
        case "SX": return ["sint maarten", "saint maarten"]
        case "TC": return ["turks and caicos", "turks and caicos islands"]
        case "TR": return ["turkey", "turkiye", "türkiye", "republic of turkey", "republic of türkiye"]
        case "TW": return ["taiwan", "republic of china taiwan", "taiwan province of china"]
        case "VA": return ["vatican", "vatican city", "holy see"]
        case "VI": return ["u s virgin islands", "us virgin islands", "virgin islands u s", "virgin islands us"]
        default: return []
        }
    }

    static func visaType(from requirement: String?) -> String? {
        let value = (requirement ?? "").lowercased()
        if value.isEmpty { return nil }
        if value.range(of: "freedom of movement", options: .regularExpression) != nil { return "freedom_of_movement" }
        if value.range(of: "visa[- ]?free|not required", options: .regularExpression) != nil { return "visa_free" }
        if value.range(of: "visa on arrival|\\bvoa\\b", options: .regularExpression) != nil { return "voa" }
        if value.range(of: "(^|\\b)e-?visa\\b|electronic travel authorization|\\beta\\b", options: .regularExpression) != nil { return "evisa" }
        if value.range(of: "entry permit|required permit", options: .regularExpression) != nil { return "entry_permit" }
        if value.range(of: "not allowed|prohibit|ban", options: .regularExpression) != nil { return "ban" }
        return "visa_required"
    }

    static func score(for visaType: String?) -> Int? {
        switch visaType {
        case "freedom_of_movement": return 100
        case "own_passport": return 100
        case "visa_free": return 100
        case "voa": return 90
        case "evisa": return 50
        case "visa_required": return 30
        case "entry_permit": return 20
        case "ban": return 0
        default: return nil
        }
    }

    static func parseDays(_ text: String?) -> Int? {
        let value = (text ?? "").lowercased()
        guard !value.isEmpty else { return nil }

        if let days = extractInt(from: value, pattern: "\\d{1,4}\\s*day") {
            return days
        }
        if let weeks = extractInt(from: value, pattern: "\\d{1,3}\\s*week") {
            return weeks * 7
        }
        if let months = extractInt(from: value, pattern: "\\d{1,2}\\s*month") {
            return months * 30
        }
        if let years = extractInt(from: value, pattern: "\\d{1,2}\\s*year") {
            return years * 365
        }

        return nil
    }

    private static func extractInt(from text: String, pattern: String) -> Int? {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(text[range])
        let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits)
    }

    static func matchRow(for country: Country, in rows: [VisaRequirementRow]) -> VisaRequirementRow? {
        let candidates = Set(([country.name] + aliases(forISO2: country.iso2)).map { normalize($0) })
        let containsCandidates = candidates.filter { candidate in
            candidate.count >= 4 && candidate.range(of: "^[a-z]{2,3}$", options: .regularExpression) == nil
        }

        if let exact = rows.first(where: { candidates.contains($0.visitorToNorm) }) {
            return exact
        }

        if let aliasMatch = rows.first(where: { row in
            guard let aliases = row.aliasesNorm else { return false }
            return !candidates.isDisjoint(with: aliases)
        }) {
            return aliasMatch
        }

        return rows.first { row in
            guard !(row.isSpecialSubregion ?? false) else { return false }
            if let parentNorm = row.parentNorm, candidates.contains(parentNorm) {
                return false
            }

            return containsCandidates.contains(where: { candidate in
                row.visitorToNorm.contains(candidate) || candidate.contains(row.visitorToNorm)
            })
        }
    }

    static func snapshot(for country: Country, rows: [VisaRequirementRow]) -> VisaSnapshot? {
        guard let row = matchRow(for: country, in: rows) else { return nil }

        let pieces = [row.requirement, row.notes]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

        return VisaSnapshot(
            passportCountryCode: row.passportFromISO2,
            passportLabel: row.passportFromRaw,
            visaType: visaType(from: row.requirement),
            visaEaseScore: score(for: visaType(from: row.requirement)),
            visaAllowedDays: parseDays(row.allowedStay) ?? parseDays(row.requirement),
            visaFeeUsd: nil,
            visaNotes: pieces.isEmpty ? nil : pieces.joined(separator: pieces.count > 1 ? ". " : ""),
            visaSourceUrl: row.sourceURL.flatMap(URL.init(string:))
        )
    }

    static func homePassportSnapshot(for country: Country, passportCountryCode: String) -> VisaSnapshot? {
        guard passportCountryCode.uppercased() == country.iso2.uppercased() else { return nil }

        let passportLabel = countryLabelLocale.localizedString(
            forRegionCode: passportCountryCode.uppercased()
        ) ?? passportCountryCode.uppercased()

        return VisaSnapshot(
            passportCountryCode: passportCountryCode.uppercased(),
            passportLabel: passportLabel,
            visaType: "own_passport",
            visaEaseScore: 100,
            visaAllowedDays: nil,
            visaFeeUsd: nil,
            visaNotes: nil,
            visaSourceUrl: nil
        )
    }
}

private struct SupabaseRESTVisaService {
    private let baseURL: URL
    private let anonKey: String
    private let decoder = JSONDecoder()

    init?() {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString)
        else {
            return nil
        }

        self.baseURL = url
        self.anonKey = anonKey
    }

    func fetchLatestVersion(passportCountryCode: String) async throws -> VisaSyncRunRow? {
        let url = baseURL
            .appendingPathComponent("rest/v1/visa_sync_runs")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "version,passport_from_raw,passport_from_iso2"),
                URLQueryItem(name: "passport_from_iso2", value: "eq.\(passportCountryCode)"),
                URLQueryItem(name: "order", value: "version.desc"),
                URLQueryItem(name: "limit", value: "1")
            ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let rows = try decoder.decode([VisaSyncRunRow].self, from: data)
        return rows.first
    }

    func fetchRequirements(passportCountryCode: String, version: Int) async throws -> [VisaRequirementRow] {
        let url = baseURL
            .appendingPathComponent("rest/v1/visa_requirements")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "passport_from_raw,passport_from_norm,passport_from_iso2,visitor_to_raw,visitor_to_norm,parent_norm,is_special_subregion,aliases_norm,requirement,allowed_stay,notes,version,source,source_url,last_verified_at"),
                URLQueryItem(name: "passport_from_iso2", value: "eq.\(passportCountryCode)"),
                URLQueryItem(name: "version", value: "eq.\(version)")
            ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        return try decoder.decode([VisaRequirementRow].self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "non-utf8"
            throw NSError(
                domain: "VisaRequirementsREST",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }
    }
}

@MainActor
final class VisaRequirementsStore: ObservableObject {
    static let shared = VisaRequirementsStore()

    @Published private(set) var latestVersion: Int?
    @Published private(set) var isRefreshing = false
    @Published private(set) var activePassportCountryCode: String?
    @Published private(set) var activePassportLabel: String?

    private let service = SupabaseRESTVisaService()
    private let versionCheckInterval: TimeInterval = 15 * 60

    private var rowsByPassport: [String: [VisaRequirementRow]] = [:]
    private var hydratedByKey: [String: HydratedVisaResult] = [:]
    private var lastVersionCheckAtByPassport: [String: Date] = [:]
    private var latestVersionByPassport: [String: Int] = [:]

    private init() {
        loadCachedDataset(for: "US")
    }

    func hydrate(
        country: Country,
        passportCountryCodes: [String]? = nil,
        fallbackPassportCountryCode: String? = nil
    ) async -> Country {
        let resolvedPassportCountryCodes = resolvedPassportCountryCodes(
            passportCountryCodes,
            fallbackPassportCountryCode: fallbackPassportCountryCode
        )
        let cached = applySnapshot(to: country, passportCountryCodes: resolvedPassportCountryCodes)

        do {
            try await refreshIfNeeded(
                passportCountryCodes: resolvedPassportCountryCodes,
                force: resolvedPassportCountryCodes.contains { rowsByPassport[$0]?.isEmpty ?? true }
            )
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Refresh failed:", error)
            #endif
        }

        return applySnapshot(to: cached, passportCountryCodes: resolvedPassportCountryCodes)
    }

    func hydrate(
        countries: [Country],
        passportCountryCodes: [String]? = nil,
        fallbackPassportCountryCode: String? = nil
    ) async -> [Country] {
        let resolvedPassportCountryCodes = resolvedPassportCountryCodes(
            passportCountryCodes,
            fallbackPassportCountryCode: fallbackPassportCountryCode
        )
        let cached = countries.map { applySnapshot(to: $0, passportCountryCodes: resolvedPassportCountryCodes) }

        do {
            try await refreshIfNeeded(
                passportCountryCodes: resolvedPassportCountryCodes,
                force: resolvedPassportCountryCodes.contains { rowsByPassport[$0]?.isEmpty ?? true }
            )
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Bulk refresh failed:", error)
            #endif
        }

        return cached.map { applySnapshot(to: $0, passportCountryCodes: resolvedPassportCountryCodes) }
    }

    private func refreshIfNeeded(passportCountryCodes: [String], force: Bool) async throws {
        guard let service else { return }
        if isRefreshing { return }

        isRefreshing = true
        defer { isRefreshing = false }

        for passportCountryCode in passportCountryCodes {
            var shouldForce = force

            if rowsByPassport[passportCountryCode] == nil {
                loadCachedDataset(for: passportCountryCode)
                shouldForce = true
            }

            if !shouldForce,
               let lastVersionCheckAt = lastVersionCheckAtByPassport[passportCountryCode],
               Date().timeIntervalSince(lastVersionCheckAt) < versionCheckInterval {
                continue
            }

            lastVersionCheckAtByPassport[passportCountryCode] = Date()

            guard let latestRun = try await service.fetchLatestVersion(passportCountryCode: passportCountryCode) else { continue }
            let remoteVersion = latestRun.version
            let currentVersion = latestVersionByPassport[passportCountryCode]
            let currentRows = rowsByPassport[passportCountryCode] ?? []
            if remoteVersion == currentVersion, !currentRows.isEmpty { continue }

            let freshRows = try await service.fetchRequirements(
                passportCountryCode: passportCountryCode,
                version: remoteVersion
            )

            latestVersionByPassport[passportCountryCode] = remoteVersion
            rowsByPassport[passportCountryCode] = freshRows
            hydratedByKey = [:]
            activePassportCountryCode = passportCountryCode
            activePassportLabel = latestRun.passportFromRaw ?? freshRows.first?.passportFromRaw
            latestVersion = remoteVersion
            saveCachedDataset(
                passportCountryCode: passportCountryCode,
                version: remoteVersion,
                rows: freshRows
            )
        }
    }

    private func applySnapshot(to country: Country, passportCountryCodes: [String]) -> Country {
        let iso2 = country.iso2.uppercased()
        let cacheKey = "\(passportCountryCodes.sorted().joined(separator: ","))::\(iso2)"

        if let cached = hydratedByKey[cacheKey] {
            return country.applyingVisa(
                visaEaseScore: cached.snapshot.visaEaseScore,
                visaType: cached.snapshot.visaType,
                visaAllowedDays: cached.snapshot.visaAllowedDays,
                visaFeeUsd: cached.snapshot.visaFeeUsd,
                visaNotes: cached.snapshot.visaNotes,
                visaSourceUrl: cached.snapshot.visaSourceUrl,
                visaPassportCode: cached.passportCode,
                visaPassportLabel: cached.passportLabel,
                visaRecommendedPassportLabel: cached.recommendedPassportLabel
            )
        }

        let snapshots = passportCountryCodes.compactMap { passportCountryCode -> VisaSnapshot? in
            if let homePassportSnapshot = VisaRowMatcher.homePassportSnapshot(
                for: country,
                passportCountryCode: passportCountryCode
            ) {
                return homePassportSnapshot
            }

            guard let rows = rowsByPassport[passportCountryCode], !rows.isEmpty else { return nil }
            return VisaRowMatcher.snapshot(for: country, rows: rows)
        }

        guard let hydratedResult = hydratedResult(from: snapshots) else {
            return country
        }

        hydratedByKey[cacheKey] = hydratedResult
        return country.applyingVisa(
            visaEaseScore: hydratedResult.snapshot.visaEaseScore,
            visaType: hydratedResult.snapshot.visaType,
            visaAllowedDays: hydratedResult.snapshot.visaAllowedDays,
            visaFeeUsd: hydratedResult.snapshot.visaFeeUsd,
            visaNotes: hydratedResult.snapshot.visaNotes,
            visaSourceUrl: hydratedResult.snapshot.visaSourceUrl,
            visaPassportCode: hydratedResult.passportCode,
            visaPassportLabel: hydratedResult.passportLabel,
            visaRecommendedPassportLabel: hydratedResult.recommendedPassportLabel
        )
    }

    private func loadCachedDataset(for passportCountryCode: String) {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: passportCountryCode)) else { return }

        do {
            let dataset = try JSONDecoder().decode(CachedVisaDataset.self, from: data)
            latestVersionByPassport[passportCountryCode] = dataset.version
            rowsByPassport[passportCountryCode] = dataset.rows
            activePassportCountryCode = dataset.passportCountryCode
            activePassportLabel = dataset.rows.first?.passportFromRaw
            latestVersion = dataset.version
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Cache decode failed:", error)
            #endif
        }
    }

    private func saveCachedDataset(passportCountryCode: String, version: Int, rows: [VisaRequirementRow]) {
        do {
            let data = try JSONEncoder().encode(
                CachedVisaDataset(
                    passportCountryCode: passportCountryCode,
                    version: version,
                    rows: rows,
                    savedAt: Date()
                )
            )
            UserDefaults.standard.set(data, forKey: cacheKey(for: passportCountryCode))
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Cache encode failed:", error)
            #endif
        }
    }

    private func resolvedPassportCountryCodes(
        _ passportCountryCodes: [String]?,
        fallbackPassportCountryCode: String?
    ) -> [String] {
        let normalizedSavedPassports = (passportCountryCodes ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }

        let normalizedFallback = fallbackPassportCountryCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let merged = normalizedSavedPassports + [normalizedFallback].compactMap { $0 }
        let unique = Array(NSOrderedSet(array: merged)) as? [String] ?? []
        return unique.isEmpty ? ["US"] : unique
    }

    private func hydratedResult(from snapshots: [VisaSnapshot]) -> HydratedVisaResult? {
        guard let bestSnapshot = snapshots.max(by: { lhs, rhs in
            compare(lhs, rhs) == .orderedAscending
        }) else {
            return nil
        }

        let bestSnapshots = snapshots.filter { compare($0, bestSnapshot) == .orderedSame }
        let sortedBestSnapshots = bestSnapshots.sorted {
            $0.passportLabel.localizedCaseInsensitiveCompare($1.passportLabel) == .orderedAscending
        }
        let bestLabels = Array(NSOrderedSet(array: sortedBestSnapshots.map(\.passportLabel))) as? [String] ?? []
        let isTie = bestLabels.count > 1

        return HydratedVisaResult(
            snapshot: sortedBestSnapshots.first ?? bestSnapshot,
            passportCode: isTie ? nil : sortedBestSnapshots.first?.passportCountryCode,
            passportLabel: bestLabels.isEmpty ? bestSnapshot.passportLabel : bestLabels.joined(separator: " / "),
            recommendedPassportLabel: isTie ? nil : bestLabels.first
        )
    }

    private func compare(_ lhs: VisaSnapshot, _ rhs: VisaSnapshot) -> ComparisonResult {
        let lhsScore = lhs.visaEaseScore ?? -1
        let rhsScore = rhs.visaEaseScore ?? -1
        if lhsScore != rhsScore {
            return lhsScore < rhsScore ? .orderedAscending : .orderedDescending
        }

        let lhsDays = lhs.visaAllowedDays ?? -1
        let rhsDays = rhs.visaAllowedDays ?? -1
        if lhsDays != rhsDays {
            return lhsDays < rhsDays ? .orderedAscending : .orderedDescending
        }

        let lhsFee = lhs.visaFeeUsd ?? .greatestFiniteMagnitude
        let rhsFee = rhs.visaFeeUsd ?? .greatestFiniteMagnitude
        if lhsFee != rhsFee {
            return lhsFee > rhsFee ? .orderedAscending : .orderedDescending
        }

        return lhs.passportCountryCode.localizedCaseInsensitiveCompare(rhs.passportCountryCode)
    }

    private func cacheKey(for passportCountryCode: String) -> String {
        "visa_requirements_cache_v2_\(passportCountryCode)"
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        var merged = components.queryItems ?? []
        merged.append(contentsOf: queryItems)
        components.queryItems = merged

        return components.url ?? self
    }
}
