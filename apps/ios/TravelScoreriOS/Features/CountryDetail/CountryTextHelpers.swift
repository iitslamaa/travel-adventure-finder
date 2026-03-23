//
//  CountryTextHelpers.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation

enum CountryTextHelpers {
    static var currentLanguageCode: String {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("pt") { return "pt" }
        if preferred.hasPrefix("fr") { return "fr" }
        if preferred.hasPrefix("es") { return "es" }
        if preferred.hasPrefix("de") { return "de" }
        if preferred.hasPrefix("it") { return "it" }
        if preferred.hasPrefix("ru") { return "ru" }
        if preferred.hasPrefix("nl") { return "nl" }
        if preferred.hasPrefix("ar") { return "ar" }
        if preferred.hasPrefix("ja") { return "ja" }
        if preferred.hasPrefix("ko") { return "ko" }
        if preferred.contains("hant") || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh-hk") || preferred.hasPrefix("zh-mo") {
            return "zh-Hant"
        }
        if preferred.hasPrefix("zh") { return "zh" }
        if preferred.hasPrefix("hi") { return "hi" }
        if preferred.hasPrefix("tr") { return "tr" }
        if preferred.hasPrefix("pl") { return "pl" }
        if preferred.hasPrefix("he") || preferred.hasPrefix("iw") { return "he" }
        if preferred.hasPrefix("sv") { return "sv" }
        if preferred.hasPrefix("fi") { return "fi" }
        if preferred.hasPrefix("da") { return "da" }
        if preferred.hasPrefix("el") { return "el" }
        if preferred.hasPrefix("id") { return "id" }
        if preferred.hasPrefix("uk") { return "uk" }
        if preferred.hasPrefix("ms") { return "ms" }
        if preferred.hasPrefix("ro") { return "ro" }
        if preferred.hasPrefix("th") { return "th" }
        if preferred.hasPrefix("vi") { return "vi" }
        if preferred.hasPrefix("cs") { return "cs" }
        if preferred.hasPrefix("hu") { return "hu" }
        return "en"
    }

    static func cleanAdvisory(_ text: String) -> String {
        var s = text

        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        s = s.replacingOccurrences(of: "\u{200B}", with: "")
        s = s.replacingOccurrences(of: "\u{FEFF}", with: "")

        s = s.replacingOccurrences(of: "â€™", with: "’")
        s = s.replacingOccurrences(of: "â€œ", with: "“")
        s = s.replacingOccurrences(of: "â€", with: "”")
        s = s.replacingOccurrences(of: "â€“", with: "–")
        s = s.replacingOccurrences(of: "â€”", with: "—")
        s = s.replacingOccurrences(of: "â€¦", with: "…")
        s = s.replacingOccurrences(of: "Â", with: "")

        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&apos;", with: "'")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "&rsquo;", with: "’")
        s = s.replacingOccurrences(of: "&lsquo;", with: "‘")
        s = s.replacingOccurrences(of: "&rdquo;", with: "”")
        s = s.replacingOccurrences(of: "&ldquo;", with: "“")
        s = s.replacingOccurrences(of: "&hellip;", with: "…")
        s = s.replacingOccurrences(of: "&mdash;", with: "—")
        s = s.replacingOccurrences(of: "&ndash;", with: "–")

        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        return s
    }

    static func advisorySummary(level: Int?) -> String {
        guard let level else {
            switch currentLanguageCode {
            case "fr":
                return "Consultez l'avis officiel le plus recent avant de voyager, car les conditions peuvent changer rapidement."
            case "es":
                return "Consulta el aviso oficial mas reciente antes de viajar, ya que las condiciones pueden cambiar rapidamente."
            case "de":
                return "Pruefen Sie vor der Reise den offiziellen Hinweis, da sich die Bedingungen schnell aendern koennen."
            case "it":
                return "Controlla l'avviso ufficiale piu recente prima di partire, perche le condizioni possono cambiare rapidamente."
            case "pt":
                return "Consulte o aviso oficial mais recente antes de viajar, pois as condicoes podem mudar rapidamente."
            case "ru":
                return "Перед поездкой проверьте официальный совет, потому что условия могут быстро меняться."
            case "nl":
                return "Controleer voor vertrek het officiele reisadvies, omdat omstandigheden snel kunnen veranderen."
            case "ar":
                return "راجع التنبيه الرسمي الاحدث قبل السفر، لان الظروف قد تتغير بسرعة."
            case "ja":
                return "状況は急に変わることがあるため、出発前に最新の公式渡航情報を確認してください。"
            case "ko":
                return "상황은 빠르게 바뀔 수 있으니 출발 전에 최신 공식 여행 권고를 확인하세요."
            case "zh":
                return "出行前请查看最新官方旅行提示，因为情况可能会迅速变化。"
            case "hi":
                return "यात्रा से पहले नवीनतम आधिकारिक सलाह जरूर देखें, क्योंकि परिस्थितियां तेजी से बदल सकती हैं।"
            case "tr":
                return "Kosullar hizla degisebilecegi icin yolculuktan once en guncel resmi uyarilari kontrol edin."
            case "pl":
                return "Przed wyjazdem sprawdz najnowsze oficjalne zalecenia, bo warunki moga szybko sie zmienic."
            case "he":
                return "לפני הנסיעה כדאי לבדוק את האזהרה הרשמית העדכנית ביותר, כי התנאים יכולים להשתנות במהירות."
            case "sv":
                return "Kontrollera de senaste officiella reseraden innan du reser, eftersom forhallandena kan andras snabbt."
            case "fi":
                return "Tarkista uusin virallinen matkustustiedote ennen matkaa, koska olosuhteet voivat muuttua nopeasti."
            case "da":
                return "Tjek de nyeste officielle rejserad inden du rejser, da forholdene hurtigt kan aendre sig."
            case "el":
                return "Ελέγξτε την πιο πρόσφατη επίσημη ταξιδιωτική οδηγία πριν ταξιδέψετε, γιατί οι συνθήκες μπορεί να αλλάξουν γρήγορα."
            case "id":
                return "Periksa anjuran resmi terbaru sebelum bepergian, karena kondisi dapat berubah dengan cepat."
            case "uk":
                return "Перед поїздкою перевірте найновіше офіційне попередження, адже умови можуть швидко змінюватися."
            case "zh-Hant":
                return "出發前請查看最新官方旅遊提示，因為情況可能會迅速變化。"
            case "ms":
                return "Semak nasihat rasmi terkini sebelum anda melancong, kerana keadaan boleh berubah dengan cepat."
            case "ro":
                return "Verifica cel mai recent aviz oficial inainte de a calatori, deoarece conditiile se pot schimba rapid."
            case "th":
                return "ตรวจสอบคำแนะนำการเดินทางอย่างเป็นทางการล่าสุดก่อนออกเดินทาง เพราะสถานการณ์อาจเปลี่ยนแปลงได้อย่างรวดเร็ว"
            case "vi":
                return "Hay kiem tra khuyen cao chinh thuc moi nhat truoc khi di, vi dieu kien co the thay doi nhanh."
            case "cs":
                return "Pred cestou si zkontrolujte nejnovejsi oficialni upozorneni, protoze podminky se mohou rychle zmenit."
            case "hu":
                return "Utazas elott ellenorizze a legfrissebb hivatalos tajekoztatast, mert a korulmenyek gyorsan valtozhatnak."
            default:
                return "Check the latest official advisory before traveling, since conditions can change quickly."
            }
        }

        switch (currentLanguageCode, level) {
        case ("fr", 1):
            return "Niveau 1: appliquez les precautions normales et consultez l'avis officiel pour les details les plus recents."
        case ("fr", 2):
            return "Niveau 2: faites preuve d'une vigilance accrue et consultez l'avis officiel pour les details les plus recents."
        case ("fr", 3):
            return "Niveau 3: reconsiderez le voyage et consultez l'avis officiel pour les details les plus recents."
        case ("fr", 4):
            return "Niveau 4: ne voyagez pas et consultez l'avis officiel pour les details les plus recents."

        case ("es", 1):
            return "Nivel 1: toma las precauciones normales y consulta el aviso oficial para ver los detalles mas recientes."
        case ("es", 2):
            return "Nivel 2: extrema la precaucion y consulta el aviso oficial para ver los detalles mas recientes."
        case ("es", 3):
            return "Nivel 3: reconsidera el viaje y consulta el aviso oficial para ver los detalles mas recientes."
        case ("es", 4):
            return "Nivel 4: no viajes y consulta el aviso oficial para ver los detalles mas recientes."

        case ("de", 1):
            return "Stufe 1: Treffen Sie normale Vorsichtsmassnahmen und lesen Sie den offiziellen Hinweis fuer aktuelle Details."
        case ("de", 2):
            return "Stufe 2: Erhoehen Sie Ihre Vorsicht und lesen Sie den offiziellen Hinweis fuer aktuelle Details."
        case ("de", 3):
            return "Stufe 3: Ueberdenken Sie die Reise und lesen Sie den offiziellen Hinweis fuer aktuelle Details."
        case ("de", 4):
            return "Stufe 4: Reisen Sie nicht und lesen Sie den offiziellen Hinweis fuer aktuelle Details."

        case ("it", 1):
            return "Livello 1: adotta le normali precauzioni e consulta l'avviso ufficiale per i dettagli piu recenti."
        case ("it", 2):
            return "Livello 2: usa maggiore cautela e consulta l'avviso ufficiale per i dettagli piu recenti."
        case ("it", 3):
            return "Livello 3: riconsidera il viaggio e consulta l'avviso ufficiale per i dettagli piu recenti."
        case ("it", 4):
            return "Livello 4: non viaggiare e consulta l'avviso ufficiale per i dettagli piu recenti."

        case ("pt", 1):
            return "Nivel 1: tome as precaucoes normais e consulte o aviso oficial para os detalhes mais recentes."
        case ("pt", 2):
            return "Nivel 2: tenha mais cautela e consulte o aviso oficial para os detalhes mais recentes."
        case ("pt", 3):
            return "Nivel 3: reavalie a viagem e consulte o aviso oficial para os detalhes mais recentes."
        case ("pt", 4):
            return "Nivel 4: nao viaje e consulte o aviso oficial para os detalhes mais recentes."

        case ("ru", 1):
            return "Уровень 1: соблюдайте обычные меры предосторожности и смотрите официальный совет для актуальных деталей."
        case ("ru", 2):
            return "Уровень 2: проявляйте повышенную осторожность и смотрите официальный совет для актуальных деталей."
        case ("ru", 3):
            return "Уровень 3: пересмотрите поездку и смотрите официальный совет для актуальных деталей."
        case ("ru", 4):
            return "Уровень 4: не путешествуйте и смотрите официальный совет для актуальных деталей."

        case ("nl", 1):
            return "Niveau 1: neem normale voorzorgsmaatregelen en bekijk het officiele reisadvies voor de nieuwste details."
        case ("nl", 2):
            return "Niveau 2: wees extra voorzichtig en bekijk het officiele reisadvies voor de nieuwste details."
        case ("nl", 3):
            return "Niveau 3: heroverweeg je reis en bekijk het officiele reisadvies voor de nieuwste details."
        case ("nl", 4):
            return "Niveau 4: reis niet en bekijk het officiele reisadvies voor de nieuwste details."

        case ("ar", 1):
            return "المستوى 1: اتخذ الاحتياطات المعتادة وراجع التنبيه الرسمي لاحدث التفاصيل."
        case ("ar", 2):
            return "المستوى 2: كن اكثر حذرا وراجع التنبيه الرسمي لاحدث التفاصيل."
        case ("ar", 3):
            return "المستوى 3: اعد النظر في السفر وراجع التنبيه الرسمي لاحدث التفاصيل."
        case ("ar", 4):
            return "المستوى 4: لا تسافر وراجع التنبيه الرسمي لاحدث التفاصيل."

        case ("ja", 1):
            return "レベル1: 通常の注意を払い、最新の詳細は公式の渡航情報を確認してください。"
        case ("ja", 2):
            return "レベル2: 一段と注意し、最新の詳細は公式の渡航情報を確認してください。"
        case ("ja", 3):
            return "レベル3: 渡航を再検討し、最新の詳細は公式の渡航情報を確認してください。"
        case ("ja", 4):
            return "レベル4: 渡航しないでください。最新の詳細は公式の渡航情報を確認してください。"

        case ("ko", 1):
            return "1단계: 일반적인 주의를 기울이고 최신 세부 내용은 공식 여행 권고를 확인하세요."
        case ("ko", 2):
            return "2단계: 각별히 주의하고 최신 세부 내용은 공식 여행 권고를 확인하세요."
        case ("ko", 3):
            return "3단계: 여행을 재고하고 최신 세부 내용은 공식 여행 권고를 확인하세요."
        case ("ko", 4):
            return "4단계: 여행하지 마세요. 최신 세부 내용은 공식 여행 권고를 확인하세요."

        case ("zh", 1):
            return "第1级：采取正常预防措施，并查看官方旅行提示了解最新细节。"
        case ("zh", 2):
            return "第2级：提高警惕，并查看官方旅行提示了解最新细节。"
        case ("zh", 3):
            return "第3级：重新考虑出行，并查看官方旅行提示了解最新细节。"
        case ("zh", 4):
            return "第4级：不要出行，并查看官方旅行提示了解最新细节。"

        case ("hi", 1):
            return "स्तर 1: सामान्य सावधानियां बरतें और नवीनतम जानकारी के लिए आधिकारिक सलाह देखें।"
        case ("hi", 2):
            return "स्तर 2: अतिरिक्त सावधानी बरतें और नवीनतम जानकारी के लिए आधिकारिक सलाह देखें।"
        case ("hi", 3):
            return "स्तर 3: यात्रा पर पुनर्विचार करें और नवीनतम जानकारी के लिए आधिकारिक सलाह देखें।"
        case ("hi", 4):
            return "स्तर 4: यात्रा न करें और नवीनतम जानकारी के लिए आधिकारिक सलाह देखें।"

        case ("tr", 1):
            return "Seviye 1: Normal onlemleri alin ve en guncel ayrintilar icin resmi uyarilari kontrol edin."
        case ("tr", 2):
            return "Seviye 2: Daha dikkatli olun ve en guncel ayrintilar icin resmi uyarilari kontrol edin."
        case ("tr", 3):
            return "Seviye 3: Seyahati yeniden degerlendirin ve en guncel ayrintilar icin resmi uyarilari kontrol edin."
        case ("tr", 4):
            return "Seviye 4: Seyahat etmeyin ve en guncel ayrintilar icin resmi uyarilari kontrol edin."

        case ("pl", 1):
            return "Poziom 1: zachowaj zwykle srodki ostroznosci i sprawdz oficjalne zalecenia po najnowsze szczegoly."
        case ("pl", 2):
            return "Poziom 2: zachowaj zwiekszona ostroznosc i sprawdz oficjalne zalecenia po najnowsze szczegoly."
        case ("pl", 3):
            return "Poziom 3: ponownie rozwaz wyjazd i sprawdz oficjalne zalecenia po najnowsze szczegoly."
        case ("pl", 4):
            return "Poziom 4: nie podrozuj i sprawdz oficjalne zalecenia po najnowsze szczegoly."

        case ("he", 1):
            return "רמה 1: נקטו באמצעי זהירות רגילים ובדקו את ההנחיות הרשמיות לפרטים העדכניים ביותר."
        case ("he", 2):
            return "רמה 2: גלו זהירות מוגברת ובדקו את ההנחיות הרשמיות לפרטים העדכניים ביותר."
        case ("he", 3):
            return "רמה 3: שקלו מחדש את הנסיעה ובדקו את ההנחיות הרשמיות לפרטים העדכניים ביותר."
        case ("he", 4):
            return "רמה 4: אל תיסעו ובדקו את ההנחיות הרשמיות לפרטים העדכניים ביותר."

        case ("sv", 1):
            return "Niva 1: vidta normala forsiktighetsatgarder och se officiella rad for de senaste detaljerna."
        case ("sv", 2):
            return "Niva 2: var extra forsiktig och se officiella rad for de senaste detaljerna."
        case ("sv", 3):
            return "Niva 3: overvag resan igen och se officiella rad for de senaste detaljerna."
        case ("sv", 4):
            return "Niva 4: res inte och se officiella rad for de senaste detaljerna."

        case ("fi", 1):
            return "Taso 1: noudata tavallista varovaisuutta ja tarkista uusimmat tiedot virallisesta tiedotteesta."
        case ("fi", 2):
            return "Taso 2: noudata erityista varovaisuutta ja tarkista uusimmat tiedot virallisesta tiedotteesta."
        case ("fi", 3):
            return "Taso 3: harkitse matkustamista uudelleen ja tarkista uusimmat tiedot virallisesta tiedotteesta."
        case ("fi", 4):
            return "Taso 4: ala matkusta ja tarkista uusimmat tiedot virallisesta tiedotteesta."

        case ("da", 1):
            return "Niveau 1: udvis normal forsigtighed og se de officielle rad for de nyeste detaljer."
        case ("da", 2):
            return "Niveau 2: vaer ekstra forsigtig og se de officielle rad for de nyeste detaljer."
        case ("da", 3):
            return "Niveau 3: overvej rejsen igen og se de officielle rad for de nyeste detaljer."
        case ("da", 4):
            return "Niveau 4: rejs ikke og se de officielle rad for de nyeste detaljer."

        case ("el", 1):
            return "Επίπεδο 1: λάβετε τις συνήθεις προφυλάξεις και δείτε την επίσημη οδηγία για τις τελευταίες λεπτομέρειες."
        case ("el", 2):
            return "Επίπεδο 2: δείξτε αυξημένη προσοχή και δείτε την επίσημη οδηγία για τις τελευταίες λεπτομέρειες."
        case ("el", 3):
            return "Επίπεδο 3: επανεξετάστε το ταξίδι και δείτε την επίσημη οδηγία για τις τελευταίες λεπτομέρειες."
        case ("el", 4):
            return "Επίπεδο 4: μην ταξιδέψετε και δείτε την επίσημη οδηγία για τις τελευταίες λεπτομέρειες."

        case ("id", 1):
            return "Level 1: lakukan kewaspadaan normal dan lihat anjuran resmi untuk rincian terbaru."
        case ("id", 2):
            return "Level 2: tingkatkan kewaspadaan dan lihat anjuran resmi untuk rincian terbaru."
        case ("id", 3):
            return "Level 3: pertimbangkan kembali perjalanan dan lihat anjuran resmi untuk rincian terbaru."
        case ("id", 4):
            return "Level 4: jangan bepergian dan lihat anjuran resmi untuk rincian terbaru."

        case ("uk", 1):
            return "Рівень 1: дотримуйтеся звичайних заходів обережності та дивіться офіційну пораду для найновіших деталей."
        case ("uk", 2):
            return "Рівень 2: будьте особливо обережні та дивіться офіційну пораду для найновіших деталей."
        case ("uk", 3):
            return "Рівень 3: перегляньте плани поїздки та дивіться офіційну пораду для найновіших деталей."
        case ("uk", 4):
            return "Рівень 4: не подорожуйте та дивіться офіційну пораду для найновіших деталей."

        case ("zh-Hant", 1):
            return "第1級：採取一般預防措施，並查看官方旅遊提示以了解最新細節。"
        case ("zh-Hant", 2):
            return "第2級：提高警覺，並查看官方旅遊提示以了解最新細節。"
        case ("zh-Hant", 3):
            return "第3級：重新考慮出行，並查看官方旅遊提示以了解最新細節。"
        case ("zh-Hant", 4):
            return "第4級：不要出行，並查看官方旅遊提示以了解最新細節。"

        case ("ms", 1):
            return "Tahap 1: ambil langkah berjaga-jaga biasa dan semak nasihat rasmi untuk butiran terkini."
        case ("ms", 2):
            return "Tahap 2: tingkatkan kewaspadaan dan semak nasihat rasmi untuk butiran terkini."
        case ("ms", 3):
            return "Tahap 3: pertimbangkan semula perjalanan dan semak nasihat rasmi untuk butiran terkini."
        case ("ms", 4):
            return "Tahap 4: jangan melancong dan semak nasihat rasmi untuk butiran terkini."

        case ("ro", 1):
            return "Nivelul 1: luati masuri normale de precautie si consultati avizul oficial pentru cele mai noi detalii."
        case ("ro", 2):
            return "Nivelul 2: manifestati prudenta sporita si consultati avizul oficial pentru cele mai noi detalii."
        case ("ro", 3):
            return "Nivelul 3: reconsiderati calatoria si consultati avizul oficial pentru cele mai noi detalii."
        case ("ro", 4):
            return "Nivelul 4: nu calatoriti si consultati avizul oficial pentru cele mai noi detalii."

        case ("th", 1):
            return "ระดับ 1: ใช้มาตรการป้องกันตามปกติและดูคำแนะนำอย่างเป็นทางการเพื่อรายละเอียดล่าสุด"
        case ("th", 2):
            return "ระดับ 2: เพิ่มความระมัดระวังและดูคำแนะนำอย่างเป็นทางการเพื่อรายละเอียดล่าสุด"
        case ("th", 3):
            return "ระดับ 3: พิจารณาการเดินทางอีกครั้งและดูคำแนะนำอย่างเป็นทางการเพื่อรายละเอียดล่าสุด"
        case ("th", 4):
            return "ระดับ 4: อย่าเดินทางและดูคำแนะนำอย่างเป็นทางการเพื่อรายละเอียดล่าสุด"

        case ("vi", 1):
            return "Cap do 1: thuc hien cac bien phap phong ngua thong thuong va xem khuyen cao chinh thuc de biet chi tiet moi nhat."
        case ("vi", 2):
            return "Cap do 2: can than hon va xem khuyen cao chinh thuc de biet chi tiet moi nhat."
        case ("vi", 3):
            return "Cap do 3: can nhac lai chuyen di va xem khuyen cao chinh thuc de biet chi tiet moi nhat."
        case ("vi", 4):
            return "Cap do 4: khong nen di va xem khuyen cao chinh thuc de biet chi tiet moi nhat."

        case ("cs", 1):
            return "Uroven 1: dodrzujte bezna bezpecnostni opatreni a sledujte oficialni upozorneni pro nejnovejsi podrobnosti."
        case ("cs", 2):
            return "Uroven 2: zvyste opatrnost a sledujte oficialni upozorneni pro nejnovejsi podrobnosti."
        case ("cs", 3):
            return "Uroven 3: znovu zvazte cestu a sledujte oficialni upozorneni pro nejnovejsi podrobnosti."
        case ("cs", 4):
            return "Uroven 4: necestujte a sledujte oficialni upozorneni pro nejnovejsi podrobnosti."

        case ("hu", 1):
            return "1. szint: tegyen szokasos ovintezkedeseket, es nezze meg a hivatalos tajekoztatast a legfrissebb reszletekert."
        case ("hu", 2):
            return "2. szint: legyen fokozottan ovatos, es nezze meg a hivatalos tajekoztatast a legfrissebb reszletekert."
        case ("hu", 3):
            return "3. szint: gondolja ujra az utazast, es nezze meg a hivatalos tajekoztatast a legfrissebb reszletekert."
        case ("hu", 4):
            return "4. szint: ne utazzon, es nezze meg a hivatalos tajekoztatast a legfrissebb reszletekert."

        case (_, 1):
            return "Level 1: exercise normal precautions and check the official advisory for the latest details."
        case (_, 2):
            return "Level 2: exercise increased caution and check the official advisory for the latest details."
        case (_, 3):
            return "Level 3: reconsider travel and check the official advisory for the latest details."
        case (_, 4):
            return "Level 4: do not travel and check the official advisory for the latest details."
        default:
            return "Check the latest official advisory before traveling, since conditions can change quickly."
        }
    }
}
