import Foundation

enum CountryOverviewDescriptionStore {
    private static let missingSentinel = "__missing_country_description__"

    private static let descriptionCodes: Set<String> = [
        "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ",
        "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS",
        "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN",
        "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE",
        "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF",
        "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM",
        "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM",
        "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC",
        "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK",
        "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA",
        "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG",
        "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW",
        "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS",
        "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO",
        "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI",
        "VN", "VU", "WF", "WS", "XD", "XK", "YE", "YT", "ZA", "ZM", "ZW",
    ]

    static func description(for country: Country) -> String {
        canonicalDescription(for: country) ?? fallbackDescription(for: country)
    }

    static func canonicalDescription(for country: Country) -> String? {
        description(forISO: country.iso2.uppercased(), localization: "en")
    }

    static func bundledLocalizedDescription(for country: Country, localeIdentifier: String) -> String? {
        let iso = country.iso2.uppercased()
        guard descriptionCodes.contains(iso) else { return nil }

        let candidates = localizationCandidates(for: localeIdentifier)
        for candidate in candidates {
            if let value = description(forISO: iso, localization: candidate) {
                return value
            }
        }

        return nil
    }

    static func missingDescriptionCodes(in countries: [Country]) -> [String] {
        let countryCodes = Set(countries.map { $0.iso2.uppercased() })
        return countryCodes.subtracting(descriptionCodes).sorted()
    }

    private static func description(forISO iso: String, localization: String) -> String? {
        guard descriptionCodes.contains(iso) else { return nil }

        let key = "country.description.\(iso.lowercased())"
        let bundle = bundle(for: localization) ?? .main
        let value = bundle.localizedString(forKey: key, value: missingSentinel, table: nil)
        guard value != missingSentinel, value != key else { return nil }
        return value
    }

    private static func bundle(for localization: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: localization, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    private static func localizationCandidates(for localeIdentifier: String) -> [String] {
        let normalized = localeIdentifier.replacingOccurrences(of: "_", with: "-")
        let lower = normalized.lowercased()

        var candidates: [String] = []
        if lower.hasPrefix("pt") {
            candidates.append("pt-BR")
        }
        if lower.hasPrefix("fr") {
            candidates.append("fr")
        }
        if lower.hasPrefix("es") {
            candidates.append("es")
        }
        if lower.hasPrefix("de") {
            candidates.append("de")
        }
        if lower.hasPrefix("it") {
            candidates.append("it")
        }
        if lower.hasPrefix("nl") {
            candidates.append("nl")
        }
        if lower.hasPrefix("ar") {
            candidates.append("ar")
        }
        if lower.hasPrefix("ja") {
            candidates.append("ja")
        }
        if lower.hasPrefix("ko") {
            candidates.append("ko")
        }
        if lower.contains("hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") || lower.hasPrefix("zh-mo") {
            candidates.append("zh-Hant")
        }
        if lower.hasPrefix("zh") {
            candidates.append("zh-Hans")
        }
        if lower.hasPrefix("ru") {
            candidates.append("ru")
        }
        if lower.hasPrefix("hi") {
            candidates.append("hi")
        }
        if lower.hasPrefix("tr") {
            candidates.append("tr")
        }
        if lower.hasPrefix("pl") {
            candidates.append("pl")
        }
        if lower.hasPrefix("he") || lower.hasPrefix("iw") {
            candidates.append("he")
        }
        if lower.hasPrefix("sv") {
            candidates.append("sv")
        }
        if lower.hasPrefix("fi") {
            candidates.append("fi")
        }
        if lower.hasPrefix("da") {
            candidates.append("da")
        }
        if lower.hasPrefix("el") {
            candidates.append("el")
        }
        if lower.hasPrefix("id") {
            candidates.append("id")
        }
        if lower.hasPrefix("uk") {
            candidates.append("uk")
        }
        if lower.hasPrefix("ms") {
            candidates.append("ms")
        }
        if lower.hasPrefix("ro") {
            candidates.append("ro")
        }
        if lower.hasPrefix("th") {
            candidates.append("th")
        }
        if lower.hasPrefix("vi") {
            candidates.append("vi")
        }
        if lower.hasPrefix("cs") {
            candidates.append("cs")
        }
        if lower.hasPrefix("hu") {
            candidates.append("hu")
        }
        if lower.hasPrefix("en") {
            candidates.append("en")
        }

        let languagePart = normalized
            .split(separator: "-")
            .first
            .map(String.init)

        if let languagePart, !candidates.contains(languagePart) {
            candidates.append(languagePart)
        }
        if !candidates.contains(normalized) {
            candidates.append(normalized)
        }
        if !candidates.contains("en") {
            candidates.append("en")
        }

        return candidates
    }

    private static func fallbackDescription(for country: Country) -> String {
        switch currentLanguageCode {
        case "ru":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) входит в регион \(label). Для этой записи в текущем наборе данных приложения пока нет полного локализованного описания, но страница страны остается доступной, пока список описаний дорабатывается."
            }
            return "\(country.localizedDisplayName) входит в набор стран приложения. Для этой записи в текущем наборе данных приложения пока нет полного локализованного описания, но страница страны остается доступной, пока список описаний дорабатывается."
        case "fr":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) fait partie de \(label). Cette fiche n'a pas encore sa description complete localisee dans les donnees actuelles de l'application, mais la page du pays reste disponible pendant que la liste est en cours de finalisation."
            }
            return "\(country.localizedDisplayName) fait partie des donnees pays de l'application. Cette fiche n'a pas encore sa description complete localisee dans les donnees actuelles de l'application, mais la page du pays reste disponible pendant que la liste est en cours de finalisation."
        case "de":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) gehoert zu \(label). Fuer diesen Eintrag liegt in den aktuellen App-Daten noch keine vollstaendig lokalisierte Laenderbeschreibung vor, aber die Landerseite bleibt verfuegbar, waehrend diese Liste fertiggestellt wird."
            }
            return "\(country.localizedDisplayName) ist im Laenderdatensatz der App enthalten. Fuer diesen Eintrag liegt in den aktuellen App-Daten noch keine vollstaendig lokalisierte Laenderbeschreibung vor, aber die Landerseite bleibt verfuegbar, waehrend diese Liste fertiggestellt wird."
        case "it":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) fa parte di \(label). Questa scheda non ha ancora una descrizione completa localizzata nell'attuale dataset dell'app, ma la pagina del paese resta disponibile mentre la raccolta viene completata."
            }
            return "\(country.localizedDisplayName) e incluso nel dataset dei paesi dell'app. Questa scheda non ha ancora una descrizione completa localizzata nell'attuale dataset dell'app, ma la pagina del paese resta disponibile mentre la raccolta viene completata."
        case "pt":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) faz parte de \(label). Esta entrada ainda nao tem sua descricao completa localizada no conjunto atual de dados do app, mas a tela do pais continua disponivel enquanto essa lista e concluida."
            }
            return "\(country.localizedDisplayName) faz parte do conjunto de paises do app. Esta entrada ainda nao tem sua descricao completa localizada no conjunto atual de dados do app, mas a tela do pais continua disponivel enquanto essa lista e concluida."
        case "es":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) forma parte de \(label). Esta entrada todavia no tiene su descripcion completa localizada en el conjunto actual de datos de la app, pero la vista del pais sigue disponible mientras se completa la lista."
            }
            return "\(country.localizedDisplayName) esta incluido en el conjunto de paises de la app. Esta entrada todavia no tiene su descripcion completa localizada en el conjunto actual de datos de la app, pero la vista del pais sigue disponible mientras se completa la lista."
        case "hi":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) \(label) का हिस्सा है। ऐप के मौजूदा डेटा सेट में इस एंट्री का पूरा स्थानीयकृत विवरण अभी उपलब्ध नहीं है, लेकिन विवरणों की सूची पूरी होने तक देश का पेज उपलब्ध रहेगा।"
            }
            return "\(country.localizedDisplayName) ऐप के देश डेटा सेट में शामिल है। ऐप के मौजूदा डेटा सेट में इस एंट्री का पूरा स्थानीयकृत विवरण अभी उपलब्ध नहीं है, लेकिन विवरणों की सूची पूरी होने तक देश का पेज उपलब्ध रहेगा।"
        case "tr":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName), \(label) bolgesinin bir parcasidir. Uygulamanin mevcut veri setinde bu kayit icin tam yerellestirilmis aciklama henuz yok, ancak aciklama listesi tamamlanirken ulke sayfasi kullanilabilir olmaya devam eder."
            }
            return "\(country.localizedDisplayName), uygulamanin ulke veri setine dahildir. Uygulamanin mevcut veri setinde bu kayit icin tam yerellestirilmis aciklama henuz yok, ancak aciklama listesi tamamlanirken ulke sayfasi kullanilabilir olmaya devam eder."
        case "pl":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) nalezy do regionu \(label). W obecnym zestawie danych aplikacji ten wpis nie ma jeszcze pelnego zlokalizowanego opisu, ale strona kraju pozostaje dostepna, dopoki lista opisow jest uzupelniana."
            }
            return "\(country.localizedDisplayName) znajduje sie w zestawie danych panstw aplikacji. W obecnym zestawie danych aplikacji ten wpis nie ma jeszcze pelnego zlokalizowanego opisu, ale strona kraju pozostaje dostepna, dopoki lista opisow jest uzupelniana."
        case "he":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) היא חלק מ-\(label). במערך הנתונים הנוכחי של האפליקציה עדיין אין לערך הזה תיאור מלא ומתורגם, אבל דף המדינה נשאר זמין בזמן שרשימת התיאורים מושלמת."
            }
            return "\(country.localizedDisplayName) כלולה במערך נתוני המדינות של האפליקציה. במערך הנתונים הנוכחי של האפליקציה עדיין אין לערך הזה תיאור מלא ומתורגם, אבל דף המדינה נשאר זמין בזמן שרשימת התיאורים מושלמת."
        case "sv":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) ar en del av \(label). I appens nuvarande datamaterial saknas fortfarande en fullstandig lokaliserad beskrivning for den har posten, men landsidan forblir tillganglig medan beskrivningslistan blir klar."
            }
            return "\(country.localizedDisplayName) ingar i appens landdataset. I appens nuvarande datamaterial saknas fortfarande en fullstandig lokaliserad beskrivning for den har posten, men landsidan forblir tillganglig medan beskrivningslistan blir klar."
        case "fi":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) kuuluu alueeseen \(label). Talle merkinnalle ei ole viela taytta lokalisoitua kuvausta sovelluksen nykyisessa aineistossa, mutta maan sivu on kaytettavissa silla aikaa kun kuvauslista viimeistellaan."
            }
            return "\(country.localizedDisplayName) kuuluu sovelluksen maadataan. Talle merkinnalle ei ole viela taytta lokalisoitua kuvausta sovelluksen nykyisessa aineistossa, mutta maan sivu on kaytettavissa silla aikaa kun kuvauslista viimeistellaan."
        case "da":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) er en del af \(label). Denne post mangler stadig sin fulde lokaliserede beskrivelse i appens nuvaerende datasat, men landesiden forbliver tilgaengelig, mens listen over beskrivelser faerdiggores."
            }
            return "\(country.localizedDisplayName) er med i appens landedatasat. Denne post mangler stadig sin fulde lokaliserede beskrivelse i appens nuvaerende datasat, men landesiden forbliver tilgaengelig, mens listen over beskrivelser faerdiggores."
        case "el":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) ανήκει στην περιοχή \(label). Αυτή η καταχώριση δεν έχει ακόμη πλήρη τοπικοποιημένη περιγραφή στα τρέχοντα δεδομένα της εφαρμογής, αλλά η σελίδα της χώρας παραμένει διαθέσιμη όσο ολοκληρώνεται η λίστα περιγραφών."
            }
            return "\(country.localizedDisplayName) περιλαμβάνεται στο σύνολο δεδομένων χωρών της εφαρμογής. Αυτή η καταχώριση δεν έχει ακόμη πλήρη τοπικοποιημένη περιγραφή στα τρέχοντα δεδομένα της εφαρμογής, αλλά η σελίδα της χώρας παραμένει διαθέσιμη όσο ολοκληρώνεται η λίστα περιγραφών."
        case "id":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) merupakan bagian dari \(label). Entri ini belum memiliki deskripsi lengkap yang dilokalkan dalam data aplikasi saat ini, tetapi halaman negara tetap tersedia sementara daftar deskripsi diselesaikan."
            }
            return "\(country.localizedDisplayName) termasuk dalam kumpulan data negara di aplikasi. Entri ini belum memiliki deskripsi lengkap yang dilokalkan dalam data aplikasi saat ini, tetapi halaman negara tetap tersedia sementara daftar deskripsi diselesaikan."
        case "uk":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) входить до регіону \(label). Для цього запису в поточному наборі даних застосунку ще немає повного локалізованого опису, але сторінка країни залишається доступною, поки список описів завершується."
            }
            return "\(country.localizedDisplayName) входить до набору даних країн застосунку. Для цього запису в поточному наборі даних застосунку ще немає повного локалізованого опису, але сторінка країни залишається доступною, поки список описів завершується."
        case "zh-Hant":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) 屬於\(label)。這筆資料在應用程式目前的資料集中還沒有完整的本地化描述，但國家頁面會在描述清單完成前保持可用。"
            }
            return "\(country.localizedDisplayName) 已包含在應用程式的國家資料集中。這筆資料在應用程式目前的資料集中還沒有完整的本地化描述，但國家頁面會在描述清單完成前保持可用。"
        case "ms":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) ialah sebahagian daripada \(label). Entri ini masih belum mempunyai penerangan setempat penuh dalam set data semasa aplikasi, tetapi halaman negara kekal tersedia sementara senarai penerangan dilengkapkan."
            }
            return "\(country.localizedDisplayName) termasuk dalam set data negara aplikasi. Entri ini masih belum mempunyai penerangan setempat penuh dalam set data semasa aplikasi, tetapi halaman negara kekal tersedia sementara senarai penerangan dilengkapkan."
        case "ro":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) face parte din \(label). Aceasta intrare nu are inca descrierea completa localizata in setul actual de date al aplicatiei, dar pagina tarii ramane disponibila in timp ce lista descrierilor este finalizata."
            }
            return "\(country.localizedDisplayName) este inclusa in setul de date al tarilor din aplicatie. Aceasta intrare nu are inca descrierea completa localizata in setul actual de date al aplicatiei, dar pagina tarii ramane disponibila in timp ce lista descrierilor este finalizata."
        case "th":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) อยู่ในภูมิภาค\(label) รายการนี้ยังไม่มีคำอธิบายฉบับแปลเต็มในชุดข้อมูลปัจจุบันของแอป แต่หน้าประเทศยังคงใช้งานได้ระหว่างที่กำลังทำรายการคำอธิบายให้เสร็จ"
            }
            return "\(country.localizedDisplayName) อยู่ในชุดข้อมูลประเทศของแอป รายการนี้ยังไม่มีคำอธิบายฉบับแปลเต็มในชุดข้อมูลปัจจุบันของแอป แต่หน้าประเทศยังคงใช้งานได้ระหว่างที่กำลังทำรายการคำอธิบายให้เสร็จ"
        case "vi":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) thuoc khu vuc \(label). Muc nay van chua co mo ta day du duoc dia phuong hoa trong bo du lieu hien tai cua ung dung, nhung trang quoc gia van co san trong khi danh sach mo ta duoc hoan tat."
            }
            return "\(country.localizedDisplayName) nam trong bo du lieu quoc gia cua ung dung. Muc nay van chua co mo ta day du duoc dia phuong hoa trong bo du lieu hien tai cua ung dung, nhung trang quoc gia van co san trong khi danh sach mo ta duoc hoan tat."
        case "cs":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) je soucasti regionu \(label). Tato polozka zatim nema plne lokalizovany popis v aktualni datove sade aplikace, ale stranka zeme zustava dostupna, zatimco se seznam popisu dokoncuje."
            }
            return "\(country.localizedDisplayName) je zahrnuta v datove sade zemi aplikace. Tato polozka zatim nema plne lokalizovany popis v aktualni datove sade aplikace, ale stranka zeme zustava dostupna, zatimco se seznam popisu dokoncuje."
        case "hu":
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) a(z) \(label) regio resze. Ehhez a bejegyzeshez az alkalmazas jelenlegi adathalmazaban meg nincs teljes lokalizalt leiras, de az orszag oldala addig is elerheto marad, amig a leirasok listaja keszul."
            }
            return "\(country.localizedDisplayName) szerepel az alkalmazas orszagadat-keszleteben. Ehhez a bejegyzeshez az alkalmazas jelenlegi adathalmazaban meg nincs teljes lokalizalt leiras, de az orszag oldala addig is elerheto marad, amig a leirasok listaja keszul."
        default:
            if let label = country.localizedRegionLabel, !label.isEmpty {
                return "\(country.localizedDisplayName) is part of \(label). This entry is missing its full custom description in the current app dataset, but the country detail view is still available while the description list is being completed."
            }
            return "\(country.localizedDisplayName) is included in the app's country dataset. This entry is missing its full custom description in the current app dataset, but the country detail view is still available while the description list is being completed."
        }
    }

    private static var currentLanguageCode: String {
        let candidates = [
            Bundle.main.preferredLocalizations.first?.lowercased(),
            Locale.autoupdatingCurrent.language.languageCode?.identifier.lowercased(),
            Locale.preferredLanguages.first?.lowercased()
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if candidate.hasPrefix("pt") { return "pt" }
            if candidate.hasPrefix("ru") { return "ru" }
            if candidate.hasPrefix("fr") { return "fr" }
            if candidate.hasPrefix("es") { return "es" }
            if candidate.hasPrefix("de") { return "de" }
            if candidate.hasPrefix("it") { return "it" }
            if candidate.hasPrefix("nl") { return "nl" }
            if candidate.hasPrefix("ar") { return "ar" }
            if candidate.hasPrefix("ja") { return "ja" }
            if candidate.hasPrefix("ko") { return "ko" }
            if candidate.contains("hant") || candidate.hasPrefix("zh-tw") || candidate.hasPrefix("zh-hk") || candidate.hasPrefix("zh-mo") { return "zh-Hant" }
            if candidate.hasPrefix("zh") { return "zh" }
            if candidate.hasPrefix("hi") { return "hi" }
            if candidate.hasPrefix("tr") { return "tr" }
            if candidate.hasPrefix("pl") { return "pl" }
            if candidate.hasPrefix("he") || candidate.hasPrefix("iw") { return "he" }
            if candidate.hasPrefix("sv") { return "sv" }
            if candidate.hasPrefix("fi") { return "fi" }
            if candidate.hasPrefix("da") { return "da" }
            if candidate.hasPrefix("el") { return "el" }
            if candidate.hasPrefix("id") { return "id" }
            if candidate.hasPrefix("uk") { return "uk" }
            if candidate.hasPrefix("ms") { return "ms" }
            if candidate.hasPrefix("ro") { return "ro" }
            if candidate.hasPrefix("th") { return "th" }
            if candidate.hasPrefix("vi") { return "vi" }
            if candidate.hasPrefix("cs") { return "cs" }
            if candidate.hasPrefix("hu") { return "hu" }
            if candidate.hasPrefix("en") { return "en" }
        }

        return "en"
    }
}
