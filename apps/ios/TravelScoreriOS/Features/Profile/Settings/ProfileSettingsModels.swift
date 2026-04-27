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
    static let supportedCodes: [String] = {
        var codes = Set(Locale.commonISOCurrencyCodes.map { $0.uppercased() })
        codes.insert("USD")

        return codes.sorted {
            let lhs = displayName(for: $0)
            let rhs = displayName(for: $1)
            if lhs != rhs {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            return $0 < $1
        }
    }()

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
        return AppDisplayLocale.current.localizedString(forCurrencyCode: normalized)
            ?? Locale(identifier: "en_US_POSIX").localizedString(forCurrencyCode: normalized)
            ?? normalized
    }

    static func symbol(for code: String, locale: Locale = AppDisplayLocale.current) -> String {
        let normalized = code.uppercased()
        if let nativeSymbol = nativeSymbolMap[normalized] {
            return nativeSymbol
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = normalized
        return formatter.currencySymbol
    }

    static func officialSymbolAssetName(for code: String) -> String? {
        switch code.uppercased() {
        case "AED":
            return "currency-symbol-aed"
        case "SAR":
            return "currency-symbol-sar"
        default:
            return nil
        }
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

    private static let nativeSymbolOverrides: [String: String] = [
        "AED": "د.إ",
        "AFN": "؋",
        "ALL": "L",
        "AMD": "֏",
        "AOA": "Kz",
        "ARS": "$",
        "AUD": "$",
        "AWG": "ƒ",
        "AZN": "₼",
        "BAM": "KM",
        "BBD": "$",
        "BDT": "৳",
        "BGN": "лв",
        "BHD": ".د.ب",
        "BIF": "FBu",
        "BMD": "$",
        "BND": "$",
        "BOB": "Bs",
        "BRL": "R$",
        "BSD": "$",
        "BTN": "Nu.",
        "BWP": "P",
        "BYN": "Br",
        "BZD": "$",
        "CAD": "$",
        "CDF": "FC",
        "CHF": "CHF",
        "CLP": "$",
        "CNY": "¥",
        "COP": "$",
        "CRC": "₡",
        "CUP": "$",
        "CVE": "$",
        "CZK": "Kč",
        "DJF": "Fdj",
        "DKK": "kr",
        "DOP": "RD$",
        "DZD": "د.ج",
        "EGP": "ج.م",
        "ERN": "Nfk",
        "ETB": "Br",
        "EUR": "€",
        "FJD": "$",
        "FKP": "£",
        "GBP": "£",
        "GEL": "₾",
        "GHS": "GH₵",
        "GIP": "£",
        "GMD": "D",
        "GNF": "FG",
        "GTQ": "Q",
        "GYD": "$",
        "HKD": "$",
        "HNL": "L",
        "HTG": "G",
        "HUF": "Ft",
        "IDR": "Rp",
        "ILS": "₪",
        "INR": "₹",
        "IQD": "ع.د",
        "IRR": "﷼",
        "ISK": "kr",
        "JMD": "$",
        "JOD": "د.أ",
        "JPY": "¥",
        "KES": "KSh",
        "KGS": "с",
        "KHR": "៛",
        "KMF": "CF",
        "KRW": "₩",
        "KWD": "د.ك",
        "KYD": "$",
        "KZT": "₸",
        "LAK": "₭",
        "LBP": "ل.ل",
        "LKR": "Rs",
        "LRD": "$",
        "LSL": "L",
        "LYD": "ل.د",
        "MAD": "د.م.",
        "MDL": "L",
        "MGA": "Ar",
        "MKD": "ден",
        "MMK": "K",
        "MNT": "₮",
        "MOP": "MOP$",
        "MRU": "UM",
        "MUR": "₨",
        "MVR": "Rf",
        "MWK": "MK",
        "MXN": "$",
        "MYR": "RM",
        "MZN": "MT",
        "NAD": "$",
        "NGN": "₦",
        "NIO": "C$",
        "NOK": "kr",
        "NPR": "रू",
        "NZD": "$",
        "OMR": "ر.ع.",
        "PAB": "B/.",
        "PEN": "S/",
        "PGK": "K",
        "PHP": "₱",
        "PKR": "₨",
        "PLN": "zł",
        "PYG": "₲",
        "QAR": "ر.ق",
        "RON": "lei",
        "RSD": "дин.",
        "RUB": "₽",
        "RWF": "FRw",
        "SAR": "ر.س",
        "SBD": "$",
        "SCR": "₨",
        "SDG": "ج.س.",
        "SEK": "kr",
        "SGD": "$",
        "SHP": "£",
        "SLE": "Le",
        "SOS": "Sh",
        "SRD": "$",
        "SSP": "£",
        "STN": "Db",
        "SYP": "£",
        "SZL": "E",
        "THB": "฿",
        "TJS": "ЅМ",
        "TMT": "m",
        "TND": "د.ت",
        "TOP": "T$",
        "TRY": "₺",
        "TTD": "TT$",
        "TWD": "$",
        "TZS": "Sh",
        "UAH": "₴",
        "UGX": "Sh",
        "USD": "$",
        "UYU": "$",
        "UZS": "so'm",
        "VES": "Bs.",
        "VND": "₫",
        "VUV": "VT",
        "WST": "WS$",
        "XAF": "FCFA",
        "XCD": "$",
        "XOF": "CFA",
        "XPF": "₣",
        "YER": "﷼",
        "ZAR": "R",
        "ZMW": "ZK"
    ]

    private static let nativeSymbolMap: [String: String] = {
        var resolved = nativeSymbolOverrides

        for code in supportedCodes where resolved[code] == nil {
            if let inferred = inferredNativeSymbol(for: code) {
                resolved[code] = inferred
            }
        }

        return resolved
    }()

    private static func inferredNativeSymbol(for code: String) -> String? {
        let normalized = code.uppercased()

        for identifier in Locale.availableIdentifiers {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: identifier)
            formatter.currencyCode = normalized

            guard formatter.currencyCode?.uppercased() == normalized else { continue }
            let symbol = formatter.currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !symbol.isEmpty, symbol != normalized, symbol != "¤" else { continue }
            return symbol
        }

        return nil
    }
}

private enum CurrencyStorageKeys {
    static let defaultCurrencyCode = "travelaf.default_currency_code"
    static let exchangeRateSnapshot = "travelaf.exchange_rate_snapshot"
}

enum AppCurrencyFormatter {
    static func numberText(
        amount: Double,
        locale: Locale = AppDisplayLocale.current,
        maximumFractionDigits: Int = 2,
        minimumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = minimumFractionDigits
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    static func string(
        amount: Double,
        currencyCode: String,
        locale: Locale = AppDisplayLocale.current,
        maximumFractionDigits: Int = 2,
        minimumFractionDigits: Int = 0
    ) -> String {
        let numberText = numberText(
            amount: amount,
            locale: locale,
            maximumFractionDigits: maximumFractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
        let symbol = AppCurrencyCatalog.symbol(for: currencyCode, locale: locale)

        return "\u{2068}\(symbol)\u{00A0}\(numberText)\u{2069}"
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

struct AppCurrencyAmountLabel: View {
    let amount: Double
    let currencyCode: String
    var font: Font = .body
    var fontSize: CGFloat = 17
    var color: Color = .primary
    var maximumFractionDigits: Int = 2
    var minimumFractionDigits: Int = 0
    var locale: Locale = AppDisplayLocale.current

    var body: some View {
        HStack(spacing: 4) {
            if let assetName = AppCurrencyCatalog.officialSymbolAssetName(for: currencyCode) {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: max(fontSize * 0.9, 12))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            } else {
                Text(AppCurrencyCatalog.symbol(for: currencyCode, locale: locale))
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(
                AppCurrencyFormatter.numberText(
                    amount: amount,
                    locale: locale,
                    maximumFractionDigits: maximumFractionDigits,
                    minimumFractionDigits: minimumFractionDigits
                )
            )
            .font(font)
            .foregroundStyle(color)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
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

private struct PublicExchangeRatePayload: Decodable {
    let result: String
    let baseCode: String
    let timeLastUpdateUnix: TimeInterval?
    let rates: [String: Double]

    enum CodingKeys: String, CodingKey {
        case result
        case baseCode = "base_code"
        case timeLastUpdateUnix = "time_last_update_unix"
        case rates
    }
}

private final class PublicExchangeRateService {
    private let feedURL = URL(string: "https://open.er-api.com/v6/latest/USD")!

    func fetchLatestRates() async throws -> ExchangeRateSnapshot {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        let payload = try JSONDecoder().decode(PublicExchangeRatePayload.self, from: data)

        guard payload.result.lowercased() == "success", !payload.rates.isEmpty else {
            throw NSError(
                domain: "CurrencyExchange",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to parse public exchange-rate feed."]
            )
        }

        var rates = payload.rates.reduce(into: [String: Double]()) { partialResult, entry in
            partialResult[entry.key.uppercased()] = entry.value
        }
        rates["USD"] = 1

        return ExchangeRateSnapshot(
            baseCurrencyCode: payload.baseCode.uppercased(),
            publishedAt: payload.timeLastUpdateUnix.map { Date(timeIntervalSince1970: $0) },
            fetchedAt: Date(),
            rates: rates
        )
    }
}

@MainActor
final class CurrencyPreferenceStore: ObservableObject {
    @Published private(set) var defaultCurrencyCode: String
    @Published private(set) var exchangeRateSnapshot: ExchangeRateSnapshot?
    @Published private(set) var isRefreshingRates = false

    private let exchangeRateService = PublicExchangeRateService()
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
            return String(
                format: String(localized: "profile.settings.currency.live_rate_dated_format"),
                locale: AppDisplayLocale.current,
                sourceCurrencyCode.uppercased(),
                rateText,
                AppDateFormatting.dateString(from: publishedAt, dateStyle: .medium)
            )
        }

        return String(
            format: String(localized: "profile.settings.currency.live_rate_format"),
            locale: AppDisplayLocale.current,
            sourceCurrencyCode.uppercased(),
            rateText
        )
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
