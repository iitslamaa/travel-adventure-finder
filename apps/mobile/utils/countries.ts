import countrySeeds from '../../web/data/seeds/countries.json';

type CountrySeed = {
  iso2?: string;
  iso3?: string;
  name?: string;
  region?: string;
  subregion?: string;
};

type CountryLookupEntry = {
  iso2: string;
  name: string;
  region?: string;
  subregion?: string;
};

const countryLookup = (countrySeeds as CountrySeed[]).reduce<Record<string, CountryLookupEntry>>(
  (lookup, country) => {
    const iso2 = country.iso2?.trim().toUpperCase();
    const iso3 = country.iso3?.trim().toUpperCase();
    const name = country.name?.trim();
    if (!iso2 || !name) return lookup;

    const entry = {
      iso2,
      name,
      region: country.region,
      subregion: country.subregion,
    };

    lookup[iso2] = entry;
    if (iso3) lookup[iso3] = entry;
    return lookup;
  },
  {}
);

export const totalCountryCount = (countrySeeds as CountrySeed[]).filter(country =>
  Boolean(country.iso2)
).length;

export function normalizeCountryCode(code: unknown) {
  if (typeof code !== 'string') return null;
  const normalized = code.trim().toUpperCase();
  return normalized || null;
}

export function countryInfo(code: unknown) {
  const normalized = normalizeCountryCode(code);
  if (!normalized) return null;
  return countryLookup[normalized] ?? null;
}

export function countryName(code: unknown) {
  const normalized = normalizeCountryCode(code);
  if (!normalized) return '';
  return countryInfo(normalized)?.name ?? normalized;
}

export function flagEmoji(code: unknown) {
  const normalized = normalizeCountryCode(code);
  const iso2 = normalized ? countryInfo(normalized)?.iso2 ?? normalized : '';
  if (!/^[A-Z]{2}$/.test(iso2)) return '';

  return iso2
    .split('')
    .map(char => String.fromCodePoint(127397 + char.charCodeAt(0)))
    .join('');
}

export function uniqueCountryCodes(codes: unknown) {
  if (!Array.isArray(codes)) return [];

  const seen = new Set<string>();
  return codes
    .map(normalizeCountryCode)
    .filter((code): code is string => {
      if (!code || seen.has(code)) return false;
      seen.add(code);
      return true;
    });
}

export function continentForCountry(code: unknown) {
  const info = countryInfo(code);
  const rawRegion = info?.region?.trim();
  const rawSubregion = info?.subregion?.trim();
  const raw = rawRegion || rawSubregion || '';

  switch (raw.toLowerCase()) {
    case 'africa':
      return 'Africa';
    case 'antarctic':
    case 'antarctica':
      return 'Antarctica';
    case 'asia':
      return 'Asia';
    case 'europe':
      return 'Europe';
    case 'oceania':
      return 'Oceania';
    case 'north america':
    case 'caribbean':
    case 'central america':
      return 'North America';
    case 'south america':
      return 'South America';
    case 'americas':
      if (rawSubregion?.toLowerCase() === 'south america') return 'South America';
      return 'North America';
    case 'latin america and the caribbean':
      return 'North America';
    default:
      return null;
  }
}
