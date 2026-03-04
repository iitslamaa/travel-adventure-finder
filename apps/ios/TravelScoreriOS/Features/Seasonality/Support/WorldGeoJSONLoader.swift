//
//  WorldGeoJSONLoader.swift
//


import Foundation
import MapKit

class CountryPolygon: MKMultiPolygon {
    var isoCode: String?
    var countryName: String?
}

struct WorldGeoJSONLoader {

    // Full-detail cache
    private static var cachedPolygons: [CountryPolygon]?

    // RN parity: ISO3 -> ISO2 map (optional file: iso3_to_iso2.json)
    private static var iso3ToIso2: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "iso3_to_iso2", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            return [:]
        }
        return json.reduce(into: [String: String]()) { result, pair in
            result[pair.key.uppercased()] = pair.value.uppercased()
        }
    }()

    private static func normalizeIso(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              raw != "-99"
        else { return nil }

        if raw == "UK" { return "GB" }
        if raw.count == 2 { return raw }
        return nil
    }

    static func loadPolygons(selectedIso: String? = nil) -> [CountryPolygon] {

        // Always use FULL dataset (no simplified switching)
        if let cached = cachedPolygons {
            return cached
        }

        let fileName = "travelaf.world.full"

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "geo.json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load \(fileName).geo.json")
            return []
        }

        let decoder = MKGeoJSONDecoder()
        guard let geoObjects = try? decoder.decode(data) else {
            print("❌ GeoJSON decode failed for \(fileName)")
            return []
        }

        var countryPolygonsByISO: [String: [MKPolygon]] = [:]
        var countryNamesByISO: [String: String] = [:]

        for object in geoObjects {
            guard let feature = object as? MKGeoJSONFeature else { continue }

            var iso: String?
            var name: String?

            if let propertiesData = feature.properties,
               let jsonObject = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: Any] {

                name =
                    (jsonObject["name"] as? String)
                    ?? (jsonObject["ADMIN"] as? String)
                    ?? (jsonObject["NAME"] as? String)

                // Force all Cyprus-related geometries (including Northern Cyprus and UN buffer zone)
                // to map to Republic of Cyprus ISO code
                if let upperName = name?.uppercased() {
                    if upperName.contains("CYPRUS") ||
                       upperName.contains("NORTHERN CYPRUS") ||
                       upperName.contains("BUFFER ZONE") {
                        iso = "CY"
                    }
                }

                // RN-style layered ISO resolution
                let nameOverrides: [String: String] = [
                    "TAIWAN": "TW",
                    "FRENCH GUIANA": "GF",
                    "MARTINIQUE": "MQ",
                    "GUADELOUPE": "GP",
                    "RÉUNION": "RE",
                    "REUNION": "RE",
                    "MAYOTTE": "YT"
                ]

                let featureName = name?.uppercased()
                let isoA2 = jsonObject["ISO_A2"] as? String
                let isoA2EH = jsonObject["ISO_A2_EH"] as? String
                let postal = jsonObject["POSTAL"] as? String
                let isoA3EH = jsonObject["ISO_A3_EH"] as? String
                let isoA3 = jsonObject["ISO_A3"] as? String
                let shapeGroup = jsonObject["shapeGroup"] as? String

                let rawIso =
                    nameOverrides[featureName ?? ""]
                    ?? normalizeIso(isoA2)
                    ?? normalizeIso(isoA2EH)
                    ?? (postal?.count == 2 ? normalizeIso(postal) : nil)
                    ?? (isoA3EH?.count == 3 ? normalizeIso(String(isoA3EH!.prefix(2))) : nil)
                    ?? (isoA3?.count == 3 ? normalizeIso(String(isoA3!.prefix(2))) : nil)
                    ?? (shapeGroup != nil ? iso3ToIso2[shapeGroup!.uppercased()] : nil)

                if iso == nil {
                    iso = normalizeIso(rawIso)
                }
            }

            guard let isoCode = iso else { continue }

            if countryNamesByISO[isoCode] == nil {
                countryNamesByISO[isoCode] = name
            }

            for geometry in feature.geometry {

                // Keep ALL rings (Polygon + MultiPolygon)
                if let polygon = geometry as? MKPolygon {
                    countryPolygonsByISO[isoCode, default: []].append(polygon)
                }
                else if let multiPolygon = geometry as? MKMultiPolygon {
                    for polygon in multiPolygon.polygons {
                        countryPolygonsByISO[isoCode, default: []].append(polygon)
                    }
                }
            }
        }

        var finalPolygons: [CountryPolygon] = []

        for (isoCode, polygons) in countryPolygonsByISO {


            guard !polygons.isEmpty else { continue }

            let countryPolygon = CountryPolygon(polygons)
            countryPolygon.isoCode = isoCode
            countryPolygon.countryName = countryNamesByISO[isoCode]

            finalPolygons.append(countryPolygon)
        }

        cachedPolygons = finalPolygons

        return finalPolygons
    }
}
