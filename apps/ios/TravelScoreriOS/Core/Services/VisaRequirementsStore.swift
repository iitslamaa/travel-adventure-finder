import Foundation
import Combine

private struct VisaSyncRunRow: Decodable {
    let version: Int
}

private struct VisaRequirementRow: Codable {
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
    let lastVerifiedAt: String?

    enum CodingKeys: String, CodingKey {
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
        case lastVerifiedAt = "last_verified_at"
    }
}

private struct CachedVisaDataset: Codable {
    let version: Int
    let rows: [VisaRequirementRow]
    let savedAt: Date
}

private struct VisaSnapshot {
    let visaType: String?
    let visaEaseScore: Int?
    let visaAllowedDays: Int?
    let visaFeeUsd: Double?
    let visaNotes: String?
    let visaSourceUrl: URL?
}

private enum VisaRowMatcher {
    static let sourceURL = URL(string: "https://en.wikipedia.org/wiki/Visa_requirements_for_United_States_citizens")

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
        let candidates = Set(([country.name] + aliases(forISO2: country.iso2)).map(normalize))
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
            visaType: visaType(from: row.requirement),
            visaEaseScore: score(for: visaType(from: row.requirement)),
            visaAllowedDays: parseDays(row.allowedStay) ?? parseDays(row.requirement),
            visaFeeUsd: nil,
            visaNotes: pieces.isEmpty ? nil : pieces.joined(separator: pieces.count > 1 ? ". " : ""),
            visaSourceUrl: sourceURL
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

    func fetchLatestVersion() async throws -> Int? {
        let url = baseURL
            .appendingPathComponent("rest/v1/visa_sync_runs")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "version"),
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
        return rows.first?.version
    }

    func fetchRequirements(version: Int) async throws -> [VisaRequirementRow] {
        let url = baseURL
            .appendingPathComponent("rest/v1/visa_requirements")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "visitor_to_raw,visitor_to_norm,parent_norm,is_special_subregion,aliases_norm,requirement,allowed_stay,notes,version,source,last_verified_at"),
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

    private let service = SupabaseRESTVisaService()
    private let cacheKey = "visa_requirements_cache_v1"
    private let versionCheckInterval: TimeInterval = 15 * 60

    private var rows: [VisaRequirementRow] = []
    private var hydratedByISO: [String: VisaSnapshot] = [:]
    private var lastVersionCheckAt: Date?

    private init() {
        loadCachedDataset()
    }

    func hydrate(country: Country) async -> Country {
        let cached = applySnapshot(to: country)

        do {
            try await refreshIfNeeded(force: rows.isEmpty)
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Refresh failed:", error)
            #endif
        }

        return applySnapshot(to: cached)
    }

    func hydrate(countries: [Country]) async -> [Country] {
        let cached = countries.map(applySnapshot(to:))

        do {
            try await refreshIfNeeded(force: rows.isEmpty)
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Bulk refresh failed:", error)
            #endif
        }

        return cached.map(applySnapshot(to:))
    }

    private func refreshIfNeeded(force: Bool) async throws {
        guard let service else { return }
        if isRefreshing { return }
        if !force, let lastVersionCheckAt, Date().timeIntervalSince(lastVersionCheckAt) < versionCheckInterval {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        lastVersionCheckAt = Date()

        guard let remoteVersion = try await service.fetchLatestVersion() else { return }
        if remoteVersion == latestVersion, !rows.isEmpty { return }

        let freshRows = try await service.fetchRequirements(version: remoteVersion)
        latestVersion = remoteVersion
        rows = freshRows
        hydratedByISO = [:]
        saveCachedDataset(version: remoteVersion, rows: freshRows)
    }

    private func applySnapshot(to country: Country) -> Country {
        let iso2 = country.iso2.uppercased()

        if let cached = hydratedByISO[iso2] {
            return country.applyingVisa(
                visaEaseScore: cached.visaEaseScore,
                visaType: cached.visaType,
                visaAllowedDays: cached.visaAllowedDays,
                visaFeeUsd: cached.visaFeeUsd,
                visaNotes: cached.visaNotes,
                visaSourceUrl: cached.visaSourceUrl
            )
        }

        guard let snapshot = VisaRowMatcher.snapshot(for: country, rows: rows) else {
            return country
        }

        hydratedByISO[iso2] = snapshot
        return country.applyingVisa(
            visaEaseScore: snapshot.visaEaseScore,
            visaType: snapshot.visaType,
            visaAllowedDays: snapshot.visaAllowedDays,
            visaFeeUsd: snapshot.visaFeeUsd,
            visaNotes: snapshot.visaNotes,
            visaSourceUrl: snapshot.visaSourceUrl
        )
    }

    private func loadCachedDataset() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }

        do {
            let dataset = try JSONDecoder().decode(CachedVisaDataset.self, from: data)
            latestVersion = dataset.version
            rows = dataset.rows
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Cache decode failed:", error)
            #endif
        }
    }

    private func saveCachedDataset(version: Int, rows: [VisaRequirementRow]) {
        do {
            let data = try JSONEncoder().encode(CachedVisaDataset(version: version, rows: rows, savedAt: Date()))
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            #if DEBUG
            print("⚠️ [VisaRequirementsStore] Cache encode failed:", error)
            #endif
        }
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
