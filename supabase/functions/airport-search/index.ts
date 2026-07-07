import "@supabase/functions-js/edge-runtime.d.ts";

type Airport = {
  iata: string;
  cityName: string;
  airportName: string;
  countryCode: string;
  type: string;
  latitude: number;
  longitude: number;
};

type AirportSuggestion = {
  cityName: string;
  countryCode: string;
  airports: Airport[];
};

const AIRPORTS_CSV_URL =
  Deno.env.get("AIRPORTS_CSV_URL") ??
  "https://davidmegginson.github.io/ourairports-data/airports.csv";
const METRO_AIRPORT_RADIUS_KM = 90;

let cachedAirports: Airport[] | null = null;
let cachedAt = 0;
const CACHE_MS = 1000 * 60 * 60 * 24;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
    },
  });
}

function parseCsvLine(line: string) {
  const values: string[] = [];
  let current = "";
  let quoted = false;

  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    const next = line[index + 1];

    if (character === '"' && quoted && next === '"') {
      current += '"';
      index += 1;
    } else if (character === '"') {
      quoted = !quoted;
    } else if (character === "," && !quoted) {
      values.push(current);
      current = "";
    } else {
      current += character;
    }
  }

  values.push(current);
  return values;
}

function normalize(value: string) {
  return value.trim().toUpperCase();
}

function titleCase(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/\b\w/g, match => match.toUpperCase());
}

function citySearchNames(cityName: string) {
  const trimmedCityName = cityName.trim();
  const names = [trimmedCityName];
  const qualifierMatch = trimmedCityName.match(/^(.+?)\s*(?:[,(\[]|\s[-–—/]\s)/);
  if (qualifierMatch?.[1]) names.push(qualifierMatch[1].trim());

  return Array.from(new Set(names.filter(Boolean)));
}

function canonicalCityName(cityName: string, normalizedQuery: string) {
  const names = citySearchNames(cityName);
  const primaryName = names[names.length - 1] ?? cityName.trim();
  if (primaryName !== cityName.trim() && normalize(primaryName).startsWith(normalizedQuery)) {
    return primaryName;
  }

  return cityName.trim();
}

async function loadAirports() {
  if (cachedAirports && Date.now() - cachedAt < CACHE_MS) return cachedAirports;

  const response = await fetch(AIRPORTS_CSV_URL);
  if (!response.ok) throw new Error(`Airport database failed with ${response.status}.`);

  const csv = await response.text();
  const lines = csv.split(/\r?\n/).filter(Boolean);
  const headers = parseCsvLine(lines[0]);
  const index = Object.fromEntries(headers.map((header, position) => [header, position]));

  cachedAirports = lines.slice(1).map(parseCsvLine).flatMap(row => {
    const iata = normalize(row[index.iata_code] ?? "");
    const cityName = (row[index.municipality] ?? "").trim();
    const airportName = (row[index.name] ?? "").trim();
    const countryCode = normalize(row[index.iso_country] ?? "");
    const latitude = Number(row[index.latitude_deg]);
    const longitude = Number(row[index.longitude_deg]);
    const scheduledService = normalize(row[index.scheduled_service] ?? "");
    const type = normalize(row[index.type] ?? "");

    if (
      iata.length !== 3 ||
      !cityName ||
      !airportName ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      scheduledService !== "YES" ||
      !["LARGE_AIRPORT", "MEDIUM_AIRPORT"].includes(type)
    ) {
      return [];
    }

    return [{
      iata,
      cityName,
      airportName,
      countryCode,
      type,
      latitude,
      longitude,
    }];
  });
  cachedAt = Date.now();
  return cachedAirports;
}

type SuggestionGroup = {
  cityName: string;
  countryCode: string;
  airports: Airport[];
  rank: number;
  qualityRank: number;
  hasCityNameMatch: boolean;
};

function cityKeyForAirport(airport: Airport, normalizedQuery: string) {
  const city = normalize(airport.cityName);
  const canonicalCity = canonicalCityName(airport.cityName, normalizedQuery);
  const normalizedCanonicalCity = normalize(canonicalCity);
  const name = normalize(airport.airportName);
  if (normalizedCanonicalCity === normalizedQuery || normalizedCanonicalCity.startsWith(normalizedQuery)) {
    return canonicalCity;
  }
  if (city === normalizedQuery || city.startsWith(normalizedQuery)) return airport.cityName;

  const nameCityCandidate = airportNameCityCandidate(airport.airportName, normalizedQuery);
  if (nameCityCandidate) return nameCityCandidate;

  const namePrefix = name.split(/[-–—]/)[0]?.trim();
  if (normalizedQuery.length >= 3 && city.includes(normalizedQuery)) return airport.cityName;
  if (normalizedQuery.length >= 3 && namePrefix && namePrefix.includes(normalizedQuery)) return titleCase(namePrefix);

  return airport.cityName;
}

function airportNameCityCandidate(airportName: string, normalizedQuery: string) {
  const normalizedName = normalize(airportName);
  if (!normalizedName.startsWith(normalizedQuery)) return null;

  const firstToken = airportName
    .replace(/[-–—/]/g, " ")
    .trim()
    .split(/\s+/)[0];

  return firstToken && normalize(firstToken).startsWith(normalizedQuery) ? titleCase(firstToken) : null;
}

function startsWithQuery(value: string, normalizedQuery: string) {
  return normalize(value).startsWith(normalizedQuery);
}

function containsQuery(value: string, normalizedQuery: string) {
  return normalize(value).includes(normalizedQuery);
}

function cityBelongsToGroup(cityName: string, normalizedGroupCityName: string) {
  return citySearchNames(cityName).some(searchName => normalize(searchName) === normalizedGroupCityName);
}

function cityNameMatchesQuery(airport: Airport, normalizedQuery: string) {
  const cityNames = citySearchNames(airport.cityName);
  return cityNames.some(cityName => startsWithQuery(cityName, normalizedQuery));
}

function airportMatches(airport: Airport, normalizedQuery: string) {
  const allowContains = normalizedQuery.length >= 3;
  const cityNames = citySearchNames(airport.cityName);
  return airport.iata === normalizedQuery
    || airport.iata.startsWith(normalizedQuery)
    || cityNames.some(cityName => startsWithQuery(cityName, normalizedQuery))
    || startsWithQuery(airport.airportName, normalizedQuery)
    || (allowContains && (
      cityNames.some(cityName => containsQuery(cityName, normalizedQuery))
    ));
}

function airportGroupRank(airport: Airport, normalizedQuery: string) {
  const city = normalize(airport.cityName);
  const cityNames = citySearchNames(airport.cityName).map(normalize);
  const name = normalize(airport.airportName);
  if (airport.iata === normalizedQuery) return 0;
  if (cityNames.some(cityName => cityName === normalizedQuery)) return 1;
  if (cityNames.some(cityName => cityName.startsWith(normalizedQuery))) return 2;
  if (name.startsWith(`${normalizedQuery} `) || name.startsWith(`${normalizedQuery}-`) || name.startsWith(normalizedQuery)) return 3;
  if (airport.iata.startsWith(normalizedQuery)) return 4;
  if (normalizedQuery.length >= 3 && city.includes(normalizedQuery)) return 5;
  if (normalizedQuery.length >= 3 && name.includes(normalizedQuery)) return 6;
  return 99;
}

function airportQualityRank(airport: Airport) {
  if (airport.type === "LARGE_AIRPORT") return 0;
  if (airport.type === "MEDIUM_AIRPORT") return 1;
  return 2;
}

function distanceKm(lhs: Airport, rhs: Airport) {
  const earthRadiusKm = 6371;
  const lhsLatitude = lhs.latitude * Math.PI / 180;
  const rhsLatitude = rhs.latitude * Math.PI / 180;
  const latitudeDelta = (rhs.latitude - lhs.latitude) * Math.PI / 180;
  const longitudeDelta = (rhs.longitude - lhs.longitude) * Math.PI / 180;
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(lhsLatitude) * Math.cos(rhsLatitude) * Math.sin(longitudeDelta / 2) ** 2;

  return 2 * earthRadiusKm * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

function compareAirports(lhs: Airport, rhs: Airport) {
  return airportQualityRank(lhs) - airportQualityRank(rhs) ||
    lhs.iata.localeCompare(rhs.iata);
}

function sortedAirports(airports: Airport[]) {
  return airports.sort(compareAirports);
}

function shouldMergeCitySuggestions(lhs: AirportSuggestion, rhs: AirportSuggestion, normalizedQuery: string) {
  if (lhs.countryCode !== rhs.countryCode) return false;
  const lhsCity = normalize(lhs.cityName);
  const rhsCity = normalize(rhs.cityName);
  return lhsCity.startsWith(normalizedQuery) &&
    rhsCity.startsWith(normalizedQuery) &&
    (lhsCity.startsWith(rhsCity) || rhsCity.startsWith(lhsCity));
}

function mergeSimilarCitySuggestions(suggestions: AirportSuggestion[], normalizedQuery: string) {
  return suggestions.reduce<AirportSuggestion[]>((merged, suggestion) => {
    const existingIndex = merged.findIndex(existing => shouldMergeCitySuggestions(existing, suggestion, normalizedQuery));
    if (existingIndex < 0) return [...merged, suggestion];

    const existing = merged[existingIndex];
    const airportsByIata = new Map<string, Airport>();
    for (const airport of [...existing.airports, ...suggestion.airports]) {
      airportsByIata.set(airport.iata, airport);
    }

    const mergedSuggestion = {
      cityName: existing.cityName.length <= suggestion.cityName.length ? existing.cityName : suggestion.cityName,
      countryCode: existing.countryCode,
      airports: sortedAirports(Array.from(airportsByIata.values())).slice(0, 8),
    };

    return [
      ...merged.slice(0, existingIndex),
      mergedSuggestion,
      ...merged.slice(existingIndex + 1),
    ];
  }, []);
}

function airportSet(suggestion: AirportSuggestion) {
  return new Set(suggestion.airports.map(airport => airport.iata));
}

function isCoveredBySuggestion(candidate: AirportSuggestion, existing: AirportSuggestion) {
  if (candidate.countryCode !== existing.countryCode) return false;
  const existingAirports = airportSet(existing);
  return candidate.airports.every(airport => existingAirports.has(airport.iata));
}

function dedupeCoveredSuggestions(suggestions: AirportSuggestion[]) {
  return suggestions.reduce<AirportSuggestion[]>((deduped, suggestion) => {
    if (deduped.some(existing => isCoveredBySuggestion(suggestion, existing))) {
      return deduped;
    }

    return [...deduped.filter(existing => !isCoveredBySuggestion(existing, suggestion)), suggestion];
  }, []);
}

function airportsForGroup(airports: Airport[], group: SuggestionGroup) {
  const normalizedCityName = normalize(group.cityName);
  const directlyMatchedAirports = airports.filter(airport =>
    airport.countryCode === group.countryCode &&
    (
      cityBelongsToGroup(airport.cityName, normalizedCityName) ||
      normalize(airport.airportName).includes(normalizedCityName)
    )
  );
  const anchorAirports = directlyMatchedAirports.filter(airport => airportQualityRank(airport) === 0);
  const anchors = anchorAirports.length > 0 ? anchorAirports : directlyMatchedAirports;
  const airportsByIata = new Map<string, Airport>();

  for (const airport of directlyMatchedAirports) {
    airportsByIata.set(airport.iata, airport);
  }

  for (const airport of airports) {
    if (
      airport.countryCode === group.countryCode &&
      anchors.some(anchor => distanceKm(anchor, airport) <= METRO_AIRPORT_RADIUS_KM)
    ) {
      airportsByIata.set(airport.iata, airport);
    }
  }

  return Array.from(airportsByIata.values()).sort((lhs, rhs) =>
    airportGroupDisplayRank(lhs, normalizedCityName) - airportGroupDisplayRank(rhs, normalizedCityName) ||
    compareAirports(lhs, rhs)
  );
}

function airportGroupDisplayRank(airport: Airport, normalizedCityName: string) {
  const isCityMatch = cityBelongsToGroup(airport.cityName, normalizedCityName);
  const isNameMatch = normalize(airport.airportName).includes(normalizedCityName);
  const quality = airportQualityRank(airport);

  if (isCityMatch && quality === 0) return 0;
  if (isNameMatch && quality === 0) return 1;
  if (quality === 0) return 2;
  if (isCityMatch) return 3;
  if (isNameMatch) return 4;
  return 5 + quality;
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return jsonResponse({ ok: true });
  if (req.method !== "GET") return jsonResponse({ ok: false, error: "GET required" }, 405);

  try {
    const url = new URL(req.url);
    const query = url.searchParams.get("query") ?? "";
    const normalizedQuery = normalize(query);
    if (normalizedQuery.length < 2) {
      return jsonResponse({ ok: true, suggestions: [] });
    }

    const airports = await loadAirports();
    const matches = airports.filter(airport => airportMatches(airport, normalizedQuery));
    const groups = new Map<string, SuggestionGroup>();

    for (const airport of matches) {
      const rankedCityName = cityKeyForAirport(airport, normalizedQuery);
      const rank = airportGroupRank(airport, normalizedQuery);
      const qualityRank = airportQualityRank(airport);
      const hasCityNameMatch = cityNameMatchesQuery(airport, normalizedQuery);
      const key = `${normalize(rankedCityName)}:${airport.countryCode}`;
      const existing = groups.get(key);

      if (existing) {
        existing.rank = Math.min(existing.rank, rank);
        existing.qualityRank = Math.min(existing.qualityRank, qualityRank);
        existing.hasCityNameMatch = existing.hasCityNameMatch || hasCityNameMatch;
      } else {
        groups.set(key, {
          cityName: rankedCityName,
          countryCode: airport.countryCode,
          airports: [],
          rank,
          qualityRank,
          hasCityNameMatch,
        });
      }
    }

    const groupedSuggestions = Array.from(groups.values());
    const hasExactCityMatch = groupedSuggestions.some(group => group.hasCityNameMatch && group.rank <= 1);
    const suggestions: AirportSuggestion[] = dedupeCoveredSuggestions(mergeSimilarCitySuggestions(groupedSuggestions
      .filter(group => !hasExactCityMatch || group.hasCityNameMatch)
      .sort((lhs, rhs) =>
        lhs.rank - rhs.rank ||
        lhs.qualityRank - rhs.qualityRank ||
        lhs.cityName.localeCompare(rhs.cityName) ||
        lhs.countryCode.localeCompare(rhs.countryCode)
      )
      .slice(0, 4)
      .map(group => {
        const cityAirports = airportsForGroup(airports, group);

        return {
          cityName: group.cityName,
          countryCode: group.countryCode,
          airports: cityAirports.slice(0, 8),
        };
      })
      .filter(suggestion => suggestion.airports.length > 0), normalizedQuery));

    console.log("[airport-search] suggestions", JSON.stringify({
      query,
      groups: suggestions.map(suggestion => ({
        cityName: suggestion.cityName,
        countryCode: suggestion.countryCode,
        airports: suggestion.airports.map(airport => airport.iata),
      })),
    }));

    return jsonResponse({ ok: true, suggestions });
  } catch (error) {
    console.error("[airport-search]", error);
    return jsonResponse({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
