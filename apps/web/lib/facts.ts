import path from 'path';
import { promises as fs } from 'fs';
import type { CountryFacts, VisaEase } from '@travel-af/shared';

// Minimal shape used from advisories; duplicated locally to avoid cross-importing route code
export type Advisory = {
  iso2?: string;
  level?: 1 | 2 | 3 | 4;
  summary?: string;
  url?: string;
};

// Numeric visa score expected by the scorer (0..100)
// We keep the original categorical value only internally for mapping.

type AdvisoryMap = Record<string, Advisory>;

function readJson<T>(rel: string): Promise<T> {
  // In Next.js App Router, process.cwd() resolves to the app root (apps/web)
  const p = path.join(process.cwd(), 'data', 'sources', rel);
  return fs.readFile(p, 'utf8').then((txt) => JSON.parse(txt) as T);
}

// --- helpers ---------------------------------------------------------------


const clamp = (x: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, x));

const advisoryToPct = (lvl?: 1 | 2 | 3 | 4) =>
  (!lvl ? undefined : clamp(((5 - lvl) / 4) * 100));

function visaCategoryToScore(v: VisaEase | undefined): number {
  switch (v) {
    case 'visa_free': return 100;
    case 'eta': return 85;
    case 'voa': return 70; // visa on arrival
    case 'visa_required': return 30;
    default: return 50; // unknown
  }
}

function affordabilityFromGdpMap(gdp: Record<string, number> | undefined, iso2: string): { afford?: number, raw?: number } {
  if (!gdp) return { afford: undefined };
  const vals = Object.values(gdp).filter((n) => Number.isFinite(n));
  if (vals.length < 2) return { afford: undefined };
  const min = Math.min(...vals);
  const max = Math.max(...vals);
  const raw = gdp[iso2];
  if (!Number.isFinite(raw)) return { afford: undefined };
  // Normalize: higher GDP PPP => less affordable. Map to 0..100 where 100=cheapest
  const norm = (raw - min) / (max - min);
  const afford = clamp(100 * (1 - norm));
  return { afford, raw };
}

function seasonalityScoreForNow(entry: number | number[] | undefined, now = new Date()): number | undefined {
  if (entry == null) return undefined;
  if (Array.isArray(entry)) {
    const month = now.getMonth() + 1; // 1..12
    return entry.includes(month) ? 100 : 50;
  }
  // already a 0..100 score
  return clamp(entry);
}

// --- main loader -----------------------------------------------------------

export async function loadFacts(iso2List: string[], advisories: Advisory[]): Promise<Record<string, CountryFacts>> {
  // Advisory lookup by ISO2 (uppercased)
  const advByIso: AdvisoryMap = {};
  for (const a of advisories) {
    if (a.iso2) advByIso[a.iso2.toUpperCase()] = a;
  }

  // Load all sources (gracefully fallback to empty objects if missing)
  const [
    gdp,
    visaRaw,
    seasonalityRaw,
    directFlightRaw,
    infrastructureRaw,
  ] = await Promise.all([
    readJson<Record<string, number>>('gdp_ppp.json').catch(() => ({} as Record<string, number>)),
    readJson<Record<string, VisaEase>>('visa_us.json').catch(() => ({} as Record<string, VisaEase>)),
    // seasonality can be either a 0..100 score OR an array of best months [1..12]
    readJson<Record<string, number | number[]>>('seasonality.json').catch(() => ({} as Record<string, number | number[]>)),
    // boolean/binary or 0..100 is okay; treat 1/true => 100, 0/false => 40 baseline
    readJson<Record<string, number | boolean>>('direct_flight.json').catch(() => ({} as Record<string, number | boolean>)),
    readJson<Record<string, number>>('infrastructure.json').catch(() => ({} as Record<string, number>)),
  ]);

  const out: Record<string, CountryFacts> = {};

  for (const iso2Raw of iso2List) {
    const iso2 = iso2Raw.toUpperCase();
    const adv = advByIso[iso2];

    const { afford, raw } = affordabilityFromGdpMap(gdp, iso2);

    // seasonality normalization
    const season = seasonalityScoreForNow(seasonalityRaw[iso2]);

    // visa score
    const visaCat = (visaRaw[iso2] ?? 'unknown') as VisaEase;
    const visaScore = visaCategoryToScore(visaCat);

    // direct flight: accept boolean or numeric 0..100
    const dfVal = directFlightRaw[iso2];
    const directFlight = typeof dfVal === 'boolean'
      ? (dfVal ? 100 : 40)
      : (Number.isFinite(dfVal as number) ? clamp(dfVal as number) : undefined);

    const infra = Number.isFinite(infrastructureRaw[iso2]) ? clamp(infrastructureRaw[iso2]) : undefined;
    // compute advisory score safely
    const advisoryScore =
      adv?.level != null
        ? advisoryToPct(adv.level)
        : undefined;

    out[iso2] = {
      iso2,
      // advisory
      advisoryLevel: adv?.level ?? undefined,
      advisoryScore,
      advisorySummary: adv?.summary ?? undefined,
      advisoryUrl: adv?.url ?? undefined,

      // logistics & experience
      seasonality: season,
      visaEase: visaScore,
      affordability: afford,
      directFlight,
      infrastructure: infra,

      // raw references kept (handy for detail pages)
      // homicidesPer100k: Number.isFinite(homicides[iso2]) ? homicides[iso2] : undefined,
      // gdpPppPerCapita: raw,
      // englishProficiency: Number.isFinite(epi[iso2]) ? clamp(epi[iso2]) : undefined,
      // visaEaseUS: visaCat,
    };
  }
  return out;
}
