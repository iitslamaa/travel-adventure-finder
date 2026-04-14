//
//  ProfileSettingsModels.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI
import Combine

enum LanguageProficiency: String, CaseIterable, Identifiable, Codable {
    case beginner
    case conversational
    case fluent

    var id: String { storageValue }

    init(storageValue: String) {
        switch storageValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fluent", "native", "advanced":
            self = .fluent
        case "conversational", "intermediate":
            self = .conversational
        default:
            self = .beginner
        }
    }

    var storageValue: String { rawValue }

    var label: String {
        switch self {
        case .beginner: return String(localized: "profile.settings.language.beginner")
        case .conversational: return String(localized: "profile.settings.language.conversational")
        case .fluent: return String(localized: "profile.settings.language.fluent")
        }
    }

    var compatibilityMultiplier: Double {
        switch self {
        case .beginner: return 0
        case .conversational: return 0.5
        case .fluent: return 1
        }
    }

    var normalizedScore: Int {
        switch self {
        case .beginner: return 0
        case .conversational: return 50
        case .fluent: return 100
        }
    }
}

enum TravelMode: String, CaseIterable, Identifiable {
    case solo, group, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .solo: return String(localized: "profile.settings.travel_mode.solo")
        case .group: return String(localized: "profile.settings.travel_mode.group")
        case .both: return String(localized: "profile.settings.travel_mode.both")
        }
    }
}

enum TravelStyle: String, CaseIterable, Identifiable {
    case budget, comfortable, inBetween, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .budget: return String(localized: "profile.settings.travel_style.budget")
        case .comfortable: return String(localized: "profile.settings.travel_style.comfortable")
        case .inBetween: return String(localized: "profile.settings.travel_style.in_between")
        case .both: return String(localized: "profile.settings.travel_style.both")
        }
    }
}

struct LanguageEntry: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var proficiency: String

    var canonicalCode: String {
        LanguageRepository.shared.canonicalLanguageCode(for: name)
        ?? name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var normalizedProficiency: LanguageProficiency {
        LanguageProficiency(storageValue: proficiency)
    }

    var display: String {
        "\(canonicalCode) (\(normalizedProficiency.label))"
    }
}

struct PassportPreferences: Codable, Equatable {
    var nationalityCountryCodes: [String]
    var passportCountryCode: String?

    static let empty = PassportPreferences(
        nationalityCountryCodes: [],
        passportCountryCode: nil
    )

    var effectivePassportCountryCode: String? {
        if let passportCountryCode,
           !passportCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return passportCountryCode.uppercased()
        }

        return nationalityCountryCodes.first?.uppercased()
    }
}

enum CountrySelectionFormatter {
    static func localizedName(for code: String) -> String {
        let upper = code.uppercased()
        return AppDisplayLocale.current.localizedString(forRegionCode: upper) ?? upper
    }

    static func label(for code: String) -> String {
        let upper = code.uppercased()
        return "\(flag(for: upper)) \(localizedName(for: upper))"
    }

    static func flag(for code: String) -> String {
        guard code.count == 2 else { return code }
        let base: UInt32 = 127397
        return code.unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}

struct ExchangeRateSnapshot: Codable, Equatable {
    let baseCurrencyCode: String
    let publishedAt: Date?
    let fetchedAt: Date
    let rates: [String: Double]
}

enum AppCurrencyCatalog {
    static let supportedCodes: [String] = [
        "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "HKD", "INR",
        "MXN", "NZD", "SGD", "THB", "TRY", "ZAR", "BRL", "DKK", "NOK", "SEK",
        "PLN", "CZK", "HUF", "RON", "ILS", "IDR", "KRW", "MYR", "PHP"
    ]

    static func isSupported(_ code: String) -> Bool {
        supportedCodes.contains(code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    static func normalizedCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isSupported(normalized) else { return nil }
        return normalized
    }

    static func displayName(for code: String) -> String {
        let normalized = code.uppercased()
        let fallbackNames: [String: String] = [
            "USD": "US Dollar",
            "EUR": "Euro",
            "GBP": "British Pound",
            "JPY": "Japanese Yen",
            "CAD": "Canadian Dollar",
            "AUD": "Australian Dollar",
            "CHF": "Swiss Franc",
            "CNY": "Chinese Yuan",
            "HKD": "Hong Kong Dollar",
            "INR": "Indian Rupee",
            "MXN": "Mexican Peso",
            "NZD": "New Zealand Dollar",
            "SGD": "Singapore Dollar",
            "THB": "Thai Baht",
            "TRY": "Turkish Lira",
            "ZAR": "South African Rand",
            "BRL": "Brazilian Real",
            "DKK": "Danish Krone",
            "NOK": "Norwegian Krone",
            "SEK": "Swedish Krona",
            "PLN": "Polish Zloty",
            "CZK": "Czech Koruna",
            "HUF": "Hungarian Forint",
            "RON": "Romanian Leu",
            "ILS": "Israeli Shekel",
            "IDR": "Indonesian Rupiah",
            "KRW": "South Korean Won",
            "MYR": "Malaysian Ringgit",
            "PHP": "Philippine Peso"
        ]

        return fallbackNames[normalized] ?? normalized
    }

    static func symbol(for code: String, locale: Locale = AppDisplayLocale.current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code.uppercased()
        return formatter.currencySymbol
    }

    static var fallbackDefaultCode: String {
        if #available(iOS 16.0, *) {
            if let localeCode = Locale.autoupdatingCurrent.currency?.identifier,
               isSupported(localeCode) {
                return localeCode
            }
        }

        return "USD"
    }
}

private enum CurrencyStorageKeys {
    static let defaultCurrencyCode = "travelaf.default_currency_code"
    static let exchangeRateSnapshot = "travelaf.exchange_rate_snapshot"
}

enum AppCurrencyFormatter {
    static func string(
        amount: Double,
        currencyCode: String,
        locale: Locale = AppDisplayLocale.current,
        maximumFractionDigits: Int = 2,
        minimumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode.uppercased()
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = minimumFractionDigits
        return formatter.string(from: NSNumber(value: amount))
            ?? "\(AppCurrencyCatalog.symbol(for: currencyCode, locale: locale))\(amount)"
    }

    static func editableText(
        amount: Double,
        locale: Locale = AppDisplayLocale.current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }
}

enum CurrencyConversion {
    static func convert(
        _ amount: Double,
        from sourceCurrencyCode: String,
        to targetCurrencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) -> Double? {
        let source = sourceCurrencyCode.uppercased()
        let target = targetCurrencyCode.uppercased()

        guard AppCurrencyCatalog.isSupported(source), AppCurrencyCatalog.isSupported(target) else {
            return nil
        }

        if source == target {
            return amount
        }

        guard let snapshot else {
            return nil
        }

        func euroReferenceRate(for code: String) -> Double? {
            if code == snapshot.baseCurrencyCode.uppercased() {
                return 1
            }
            return snapshot.rates[code]
        }

        guard let sourceRate = euroReferenceRate(for: source),
              let targetRate = euroReferenceRate(for: target),
              sourceRate > 0,
              targetRate > 0 else {
            return nil
        }

        let amountInEuro = source == snapshot.baseCurrencyCode.uppercased()
            ? amount
            : amount / sourceRate
        return target == snapshot.baseCurrencyCode.uppercased()
            ? amountInEuro
            : amountInEuro * targetRate
    }
}

private final class ECBExchangeRateXMLParserDelegate: NSObject, XMLParserDelegate {
    private(set) var publishedAt: Date?
    private(set) var rates: [String: Double] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if let dateString = attributeDict["time"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            publishedAt = formatter.date(from: dateString)
            return
        }

        guard let currencyCode = attributeDict["currency"]?.uppercased(),
              let rateString = attributeDict["rate"],
              let rate = Double(rateString),
              AppCurrencyCatalog.isSupported(currencyCode) else {
            return
        }

        rates[currencyCode] = rate
    }
}

private final class ECBExchangeRateService {
    private let feedURL = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!

    func fetchLatestRates() async throws -> ExchangeRateSnapshot {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        let delegate = ECBExchangeRateXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw NSError(
                domain: "CurrencyExchange",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to parse ECB exchange-rate feed."]
            )
        }

        return ExchangeRateSnapshot(
            baseCurrencyCode: "EUR",
            publishedAt: delegate.publishedAt,
            fetchedAt: Date(),
            rates: delegate.rates
        )
    }
}

@MainActor
final class CurrencyPreferenceStore: ObservableObject {
    @Published private(set) var defaultCurrencyCode: String
    @Published private(set) var exchangeRateSnapshot: ExchangeRateSnapshot?
    @Published private(set) var isRefreshingRates = false

    private let exchangeRateService = ECBExchangeRateService()
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.defaultCurrencyCode = Self.persistedDefaultCurrencyCode(userDefaults: userDefaults)
        self.exchangeRateSnapshot = Self.persistedExchangeRateSnapshot(userDefaults: userDefaults)

        Task {
            await refreshRatesIfNeeded()
        }
    }

    func setDefaultCurrency(_ code: String) {
        guard let normalized = AppCurrencyCatalog.normalizedCode(code) else { return }
        defaultCurrencyCode = normalized
        userDefaults.set(normalized, forKey: CurrencyStorageKeys.defaultCurrencyCode)
    }

    func synchronizeProfileCurrency(_ code: String?) {
        guard let normalized = AppCurrencyCatalog.normalizedCode(code) else { return }
        guard normalized != defaultCurrencyCode else { return }
        setDefaultCurrency(normalized)
    }

    func refreshRatesIfNeeded(force: Bool = false) async {
        guard force || shouldRefreshRates else { return }

        isRefreshingRates = true
        defer { isRefreshingRates = false }

        do {
            let snapshot = try await exchangeRateService.fetchLatestRates()
            exchangeRateSnapshot = snapshot
            persistExchangeRateSnapshot(snapshot, userDefaults: userDefaults)
        } catch {
            // Keep the latest cached snapshot on failures.
        }
    }

    func convertedAmountFromUSD(_ amount: Double, to currencyCode: String) -> Double {
        let normalized = AppCurrencyCatalog.normalizedCode(currencyCode) ?? "USD"
        return CurrencyConversion.convert(
            amount,
            from: "USD",
            to: normalized,
            snapshot: exchangeRateSnapshot
        ) ?? amount
    }

    func convertedAmountToUSD(_ amount: Double, from currencyCode: String) -> Double {
        let normalized = AppCurrencyCatalog.normalizedCode(currencyCode) ?? "USD"
        return CurrencyConversion.convert(
            amount,
            from: normalized,
            to: "USD",
            snapshot: exchangeRateSnapshot
        ) ?? amount
    }

    func formatFromUSD(
        _ amount: Double,
        currencyCode: String? = nil,
        locale: Locale = .autoupdatingCurrent,
        maximumFractionDigits: Int = 2,
        minimumFractionDigits: Int = 0
    ) -> String {
        let targetCode = AppCurrencyCatalog.normalizedCode(currencyCode) ?? defaultCurrencyCode
        let converted = convertedAmountFromUSD(amount, to: targetCode)
        return AppCurrencyFormatter.string(
            amount: converted,
            currencyCode: targetCode,
            locale: locale,
            maximumFractionDigits: maximumFractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
    }

    func exchangeRateDescription(
        from sourceCurrencyCode: String = "USD",
        to targetCurrencyCode: String,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        let target = AppCurrencyCatalog.normalizedCode(targetCurrencyCode) ?? defaultCurrencyCode
        let converted = CurrencyConversion.convert(
            1,
            from: sourceCurrencyCode.uppercased(),
            to: target,
            snapshot: exchangeRateSnapshot
        )

        guard let converted else {
            return nil
        }

        let rateText = AppCurrencyFormatter.string(
            amount: converted,
            currencyCode: target,
            locale: locale,
            maximumFractionDigits: 4,
            minimumFractionDigits: 2
        )

        if let publishedAt = exchangeRateSnapshot?.publishedAt {
            return "ECB rate: 1 \(sourceCurrencyCode.uppercased()) = \(rateText) • \(AppDateFormatting.dateString(from: publishedAt, dateStyle: .medium))"
        }

        return "ECB rate: 1 \(sourceCurrencyCode.uppercased()) = \(rateText)"
    }

    private var shouldRefreshRates: Bool {
        guard let snapshot = exchangeRateSnapshot else { return true }

        let calendar = Calendar.current
        if let publishedAt = snapshot.publishedAt,
           calendar.isDateInToday(publishedAt) {
            return false
        }

        if let twelveHoursAgo = calendar.date(byAdding: .hour, value: -12, to: Date()) {
            return snapshot.fetchedAt < twelveHoursAgo
        }

        return true
    }

    static func persistedDefaultCurrencyCode(userDefaults: UserDefaults = .standard) -> String {
        if let saved = AppCurrencyCatalog.normalizedCode(
            userDefaults.string(forKey: CurrencyStorageKeys.defaultCurrencyCode)
        ) {
            return saved
        }

        return AppCurrencyCatalog.fallbackDefaultCode
    }

    static func persistedExchangeRateSnapshot(userDefaults: UserDefaults = .standard) -> ExchangeRateSnapshot? {
        guard let data = userDefaults.data(forKey: CurrencyStorageKeys.exchangeRateSnapshot) else {
            return nil
        }

        return try? JSONDecoder().decode(ExchangeRateSnapshot.self, from: data)
    }

    private func persistExchangeRateSnapshot(_ snapshot: ExchangeRateSnapshot, userDefaults: UserDefaults) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(encoded, forKey: CurrencyStorageKeys.exchangeRateSnapshot)
    }
}
