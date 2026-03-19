import { NextResponse } from 'next/server';
import { COUNTRY_SEEDS, byIso2 } from '@/lib/seed';
import { headers, cookies } from 'next/headers';
import type { CountrySeed } from '@/lib/types';
import { loadFacts } from '@/lib/facts';
import type { CountryFacts } from '@travel-af/shared';

import fs from 'node:fs/promises';
import path from 'node:path';

import { gdpPerCapitaUSDMap } from '@/lib/providers/worldbank';
import { fxLocalPerUSDMapByIso2 } from '@/lib/providers/fx';
import {
  COUNTRY_SEASONALITY_DEFINITIONS,
  type CountrySeasonalityDefinition,
} from '../../../../../packages/data/src/countrySeasonality';
import { buildVisaIndex } from '@/lib/providers/visa';
import { estimateDailySpendHotel } from '@/lib/providers/costs';
import type { DailySpend } from '@/lib/providers/costs';
import { buildRows, DEFAULT_WEIGHTS } from '@travel-af/domain/src/scoring';
import { createServerClient } from '@supabase/auth-helpers-nextjs';
import {
  computeLanguageCompatibilityScore,
  parseProfileLanguages,
  type CountryLanguageCoverage,
} from '@/lib/languageCompatibility';


// Local type to avoid any
type FactsExtraServer = Partial<CountryFacts> & {
  seasonality?: number;
  visaEase?: number;
  visaType?:
    | 'freedom_of_movement'
    | 'visa_free'
    | 'voa'
    | 'evisa'
    | 'visa_required'
    | 'entry_permit'
    | 'ban';
  visaAllowedDays?: number;
  visaFeeUsd?: number;
  visaNotes?: string;
  visaSource?: string;
  directFlight?: number;
  infrastructure?: number;
  // affordability inputs
  costOfLivingIndex?: number;
  foodCostIndex?: number;
  housingCostIndex?: number;
  transportCostIndex?: number;
  gdpPerCapitaUsd?: number;
  fxLocalPerUSD?: number;
  localPerUSD?: number;
  usdToLocalRate?: number;
  affordability?: number;          // final 0–100 affordability score (cheap = 100)
  dailySpend?: DailySpend;

  // server-computed affordability details
  averageDailyCostUsd?: number;    // per-person daily cost in USD
  affordabilityCategory?: number;  // 1 (cheapest) .. 10 (most expensive)
  affordabilityBand?: 'good' | 'warn' | 'bad' | 'danger';  // centralized UI band
  affordabilityExplanation?: string;
  languageCompatibilityScore?: number;

  // server-computed total
  scoreTotal?: number;
  // FM (Frequent Miler) seasonality enrichments
  fmSeasonalityBestMonths?: number[];            // 1..12
  fmSeasonalityShoulderMonths?: number[];
  fmSeasonalityGoodMonths?: number[];
  fmSeasonalityAvoidMonths?: number[];
  fmSeasonalityAreas?: { area?: string; months: number[] }[];
  fmSeasonalityHasDualPeak?: boolean;
  fmSeasonalityTodayScore?: number;              // 0..100
  fmSeasonalityTodayLabel?: 'best' | 'good' | 'shoulder' | 'poor';
  fmSeasonalitySource?: string;
  fmSeasonalityNotes?: string;
};


function decodeHtmlEntitiesServer(input?: string): string | undefined {
  if (!input) return input;

  let s = input
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => {
      const cp = parseInt(hex, 16);
      return Number.isFinite(cp) ? String.fromCodePoint(cp) : _;
    })
    .replace(/&#(\d+);/g, (_, num) => {
      const cp = parseInt(num, 10);
      return Number.isFinite(cp) ? String.fromCodePoint(cp) : _;
    });

  s = s
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');

  return s
    .replace(/[\u00a0\u202f\u2007]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function inheritMicrostateAdvisory(
  iso2: string,
  overlay: Map<string, Advisory>
): Advisory | undefined {
  // Italy microstates
  if (iso2 === 'SM' || iso2 === 'VA') {
    return overlay.get('IT');
  }

  // Monaco → France
  if (iso2 === 'MC') {
    return overlay.get('FR');
  }

  return undefined;
}

// --- Frequent Miler helpers -------------------------------------------------
function clusterConsecutiveMonths(months: number[]): number[][] {
  if (!months.length) return [];
  const sorted = [...new Set(months.filter(m => m>=1 && m<=12))].sort((a,b)=>a-b);
  const groups: number[][] = [];
  let group: number[] = [sorted[0]];
  for (let i=1;i<sorted.length;i++) {
    if (sorted[i] === sorted[i-1] + 1) group.push(sorted[i]);
    else { groups.push(group); group = [sorted[i]]; }
  }
  groups.push(group);
  // merge wrap (Dec->Jan)
  const first = groups[0], last = groups[groups.length-1];
  if (first && last && first[0] === 1 && last[last.length-1] === 12) {
    groups[0] = [...last, ...first];
    groups.pop();
  }
  return groups;
}
function fmTodayLabel(score?: number): 'best'|'good'|'shoulder'|'poor' {
  if (score == null) return 'shoulder';
  if (score >= 95) return 'best';
  if (score >= 75) return 'shoulder';
  if (score >= 30) return 'good';
  return 'poor';
}

function advisoryToScore(level?: 1|2|3|4) {
  if (!level) return 50; // neutral when missing
  return ((5 - level) / 4) * 100;
}
function extractAverageDailyCostUsd(fx: FactsExtraServer): number | undefined {
  const spend = fx.dailySpend as unknown as {
    totalUsd?: number;
    totalUSD?: number;
    hotelUsd?: number;
    hostelUsd?: number;
    foodUsd?: number;
    transportUsd?: number;
  } | undefined;

  if (!spend) return undefined;

  if (typeof spend.totalUsd === 'number') return spend.totalUsd;
  if (typeof spend.totalUSD === 'number') return spend.totalUSD;

  const parts: number[] = [];
  if (typeof spend.hotelUsd === 'number') parts.push(spend.hotelUsd);
  if (typeof spend.hostelUsd === 'number') parts.push(spend.hostelUsd);
  if (typeof spend.foodUsd === 'number') parts.push(spend.foodUsd);
  if (typeof spend.transportUsd === 'number') parts.push(spend.transportUsd);

  if (!parts.length) return undefined;
  return parts.reduce((a, b) => a + b, 0);
}

function affordabilityBandFromCategory(
  category?: number
): 'good' | 'warn' | 'bad' | 'danger' | undefined {
  if (category == null) return undefined;

  // 1–3 = cheapest → green (good)
  if (category >= 1 && category <= 3) return 'good';

  // 4–5 → yellow
  if (category >= 4 && category <= 5) return 'warn';

  // 6–7 → orange
  if (category >= 6 && category <= 7) return 'bad';

  // 8–10 → red (most expensive)
  if (category >= 8 && category <= 10) return 'danger';

  return undefined;
}


// Best-effort optional JSON imports (files may not exist in all demos)
// We read JSON directly from the filesystem so this works reliably in Node/Next.
async function safeJsonImport<T = Record<string, unknown>>(relativePath: string): Promise<T | null> {
  try {
    const fullPath = path.join(process.cwd(), relativePath);
    const raw = await fs.readFile(fullPath, 'utf8');
    return JSON.parse(raw) as T;
  } catch (err) {
    console.warn('[countries] safeJsonImport failed for', relativePath, err);
    return null;
  }
}

type Advisory = {
  iso2: string; // REQUIRED: ISO-3166-1 alpha-2 (uppercased)
  country?: string;
  level: 1 | 2 | 3 | 4;
  updatedAt?: string;  // normalized
  url?: string;
  summary?: string;
};

type CountryOut = CountrySeed & {
  advisory: null | { level: 1|2|3|4; score: number; updatedAt: string; url: string; summary: string };
  facts?: FactsExtraServer;
};

type UserScorePreferencesRow = {
  advisory?: number | null;
  seasonality?: number | null;
  visa?: number | null;
  affordability?: number | null;
  language?: number | null;
};

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const lite = searchParams.get('lite') === '1';
  // Build absolute base to call our other route reliably in dev/prod
  const h = await headers();
  const vercel = h.get('x-vercel-deployment-url'); // e.g. myapp-abc123.vercel.app
  const host = vercel ?? h.get('x-forwarded-host') ?? h.get('host') ?? '';
  const envBase = process.env.NEXT_PUBLIC_BASE_URL?.replace(/\/+$/, '');
  const proto = vercel ? 'https' : (h.get('x-forwarded-proto') ?? (host.includes('localhost') ? 'http' : 'https'));
  const base = envBase || (host ? `${proto}://${host}` : '');


  // --- Fetch user-specific score weights from Supabase (if authenticated)
  let userWeights = DEFAULT_WEIGHTS;
  try {
    const cookieStore = await cookies();

    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          get(name: string) {
            return cookieStore.get(name)?.value;
          },
        },
      }
    );

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      const { data } = await supabase
        .from('user_score_preferences')
        // DB columns are: affordability, visa, advisory, seasonality, language
        .select('advisory, seasonality, visa, affordability, language')
        .eq('user_id', user.id)
        .maybeSingle();

      if (data) {
        const prefs = data as UserScorePreferencesRow;

        userWeights = {
          // Domain expects `travelGov`; DB stores this as `advisory`
          travelGov: prefs.advisory ?? DEFAULT_WEIGHTS.travelGov,
          seasonality: prefs.seasonality ?? DEFAULT_WEIGHTS.seasonality,
          visa: prefs.visa ?? DEFAULT_WEIGHTS.visa,
          affordability: prefs.affordability ?? DEFAULT_WEIGHTS.affordability,
          language: prefs.language ?? DEFAULT_WEIGHTS.language,
        };

        console.log('[countries] loaded userWeights', {
          userId: user.id,
          userWeights,
        });
      }
    }
  } catch (err) {
    console.warn('[countries] failed to load user weights, using defaults', err);
  }

  let userProfileLanguages: ReturnType<typeof parseProfileLanguages> = [];
  try {
    const cookieStore = await cookies();

    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          get(name: string) {
            return cookieStore.get(name)?.value;
          },
        },
      }
    );

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      const { data } = await supabase
        .from('profiles')
        .select('languages')
        .eq('id', user.id)
        .maybeSingle();

      userProfileLanguages = parseProfileLanguages(data?.languages);
    }
  } catch (err) {
    console.warn('[countries] failed to load user profile languages', err);
  }

  let advisories: Advisory[] = [];
  try {
    const advUrl = base ? `${base}/api/advisories` : '/api/advisories';
    const advRes = await fetch(advUrl, { cache: 'no-store' });
    const rawUnknown = advRes.ok ? ((await advRes.json()) as unknown) : null;
    if (!advRes.ok || !Array.isArray(rawUnknown)) {
      console.error('[countries] advisories upstream bad', { status: advRes.status, url: advUrl });
    }

    type AdvRaw = Partial<{
      iso2: string;
      country: string;
      level: number | string;
      updatedAt: string;
      updated: string;
      url: string;
      summary: string;
    }>;

    const raw: AdvRaw[] = Array.isArray(rawUnknown) ? (rawUnknown as AdvRaw[]) : [];

    advisories = raw.flatMap((r) => {
      const iso2 = typeof r.iso2 === 'string' && /^[A-Za-z]{2}$/.test(r.iso2)
        ? r.iso2.toUpperCase()
        : null;

      if (!iso2) return [];

      const lvl = Number(r.level ?? 0);
      const level: 1 | 2 | 3 | 4 =
        (lvl === 1 || lvl === 2 || lvl === 3 || lvl === 4)
          ? (lvl as 1 | 2 | 3 | 4)
          : 2;

      return [{
        iso2,
        country: typeof r.country === 'string' ? r.country : undefined,
        level,
        updatedAt: typeof r.updatedAt === 'string'
          ? r.updatedAt
          : (typeof r.updated === 'string' ? r.updated : undefined),
        url: typeof r.url === 'string' ? r.url : undefined,
        summary: decodeHtmlEntitiesServer(typeof r.summary === 'string' ? r.summary : undefined),
      }];
    });
  } catch (err) {
    console.error('[countries] advisories fetch failed', err);
    advisories = [];
  }

    // STRICT normalization: advisories MUST have a valid ISO2.
    // This prevents fuzzy/name-based misassignment (e.g., Myanmar/Burma bleeding into Argentina).
    advisories = advisories
      .map((a) => {
        const iso2 = typeof a.iso2 === 'string' && /^[A-Za-z]{2}$/.test(a.iso2)
          ? a.iso2.toUpperCase()
          : null;
        return iso2 ? { ...a, iso2 } : null;
      })
      .filter((a): a is Advisory => a !== null);

  const overlay = new Map<string, Advisory>();
  for (const a of advisories) {
    overlay.set(a.iso2, a);
  }
  console.log('[countries] overlay size:', overlay.size);

  // Merge overlay onto seeds, keep every seed (full coverage)
  const merged: CountryOut[] = COUNTRY_SEEDS.map((seed) => {
    const iso2 = seed.iso2.toUpperCase();

    // 1) U.S. territories never receive State Dept advisories
    // (Guam, American Samoa, USVI, Northern Mariana Islands, etc.)
    if (seed.territory === true && seed.iso2.startsWith('U')) {
      return { ...seed, advisory: null };
    }

    // 2) Primary advisory from RSS/snapshot
    let adv = overlay.get(iso2);

    // 3) Microstate inheritance (ONLY if no direct advisory)
    if (!adv) {
      adv = inheritMicrostateAdvisory(iso2, overlay);
    }

    return {
      ...seed,
      advisory: adv
        ? {
            level: adv.level,
            score: advisoryToScore(adv.level),
            updatedAt: adv.updatedAt || '',
            url: adv.url || '',
            summary: decodeHtmlEntitiesServer(adv.summary) ?? '',
          }
        : null,
    };
  });

  // Include advisory-only places not in seed (rare if seed is full UN list)
  for (const a of advisories) {
    const key = a.iso2;
    if (key && !byIso2.has(key)) {
      const extra: CountryOut = {
        iso2: key,
        iso3: key, // placeholder until we have full mapping
        m49: 0,
        name: a.country,
        aliases: [],
        region: undefined,
        subregion: undefined,
        territory: true,
        advisory: {
          level: a.level,
          score: advisoryToScore(a.level),
          updatedAt: a.updatedAt || '',
          url: a.url || '',
          summary: decodeHtmlEntitiesServer(a.summary) ?? '',
        },
      } as CountryOut;
      merged.push(extra);
    }
  }

  // Load and attach facts (advisory, SFTI, Reddit, visa, seasonality, flights, infrastructure, affordability)
  if (lite) {
    merged.sort((x, y) => x.name.localeCompare(y.name));

    console.log('[countries] returning LITE payload');

    return NextResponse.json(
      merged.map((c) => ({
        iso2: c.iso2,
        name: c.name,
        region: c.region,
        subregion: c.subregion,
        advisory: c.advisory,
      }))
    );
  }
  try {
    const iso2s = merged.map((r) => r.iso2.toUpperCase());

    // Disable caching for downstream fetches (e.g. Wikipedia HTML) to avoid Next.js cache warnings
    const factsByIso2 = await loadFacts(iso2s, advisories);
    const visaIndex = await buildVisaIndex();

    // --- Fetch live macroeconomic indicators ---
    const [liveGdpMap, liveFxMap] = await Promise.all([
      gdpPerCapitaUSDMap(iso2s),
      fxLocalPerUSDMapByIso2(iso2s),
    ]);
    const costsByIso2: Map<string, DailySpend> = await (async () => {
      try {
        const mod = await import('@/lib/providers/costs');
        const fn = (mod as { buildCostIndex?: () => Promise<Map<string, DailySpend>> }).buildCostIndex;
        return fn ? await fn() : new Map<string, DailySpend>();
      } catch {
        return new Map<string, DailySpend>();
      }
    })();

    // Optionally enrich facts with macro signals for affordability + themes
    // These files are optional; if missing we proceed without them.

    const [
      colJson,
      foodJson,
      housingJson,
      transportJson,
    ] = await Promise.all([
      safeJsonImport<Record<string, number>>("data/sources/cost_of_living.json"),
      safeJsonImport<Record<string, number>>("data/sources/food_index.json"),
      safeJsonImport<Record<string, number>>("data/sources/housing_index.json"),
      safeJsonImport<Record<string, number>>("data/sources/transport_index.json"),
    ]);

    console.log('[countries] affordability JSON presence', {
      hasColJson: !!colJson,
      hasFoodJson: !!foodJson,
      hasHousingJson: !!housingJson,
      hasTransportJson: !!transportJson,
    });

    // Normalize keys to ISO2 uppercase where possible
    function toIso2Key(k: string): string {
      return k?.toUpperCase?.() ?? k;
    }
    const gdpMap: Record<string, number> = {};
    const fxMap: Record<string, number> = {};
    const colMap: Record<string, number> = Object.fromEntries(
      Object.entries(colJson ?? {}).map(([k, v]) => [toIso2Key(k), Number(v)])
    );
    const foodMap: Record<string, number> = Object.fromEntries(
      Object.entries(foodJson ?? {}).map(([k, v]) => [toIso2Key(k), Number(v)])
    );
    const housingMap: Record<string, number> = Object.fromEntries(
      Object.entries(housingJson ?? {}).map(([k, v]) => [toIso2Key(k), Number(v)])
    );
    const transportMap: Record<string, number> = Object.fromEntries(
      Object.entries(transportJson ?? {}).map(([k, v]) => [toIso2Key(k), Number(v)])
    );
    const themesMap: Record<string, string[]> = {};

    console.log('[countries] affordability map samples', {
      colKeys: Object.keys(colMap).slice(0, 10),
      foodKeys: Object.keys(foodMap).slice(0, 10),
      housingKeys: Object.keys(housingMap).slice(0, 10),
      transportKeys: Object.keys(transportMap).slice(0, 10),
    });

    const todayMonth = new Date().getMonth() + 1; // 1..12

    for (const row of merged) {
      const keyUpper = row.iso2.toUpperCase();
      const facts = factsByIso2[keyUpper] ?? factsByIso2[row.iso2] ?? undefined;

      // Merge optional macro signals for affordability and narrative if we have them
      const extra: Partial<CountryFacts & {
        costOfLivingIndex?: number;
        foodCostIndex?: number; // reserved; currently same as COL if specific food index missing
        housingCostIndex?: number;
        transportCostIndex?: number;
        gdpPerCapitaUsd?: number;
        fxLocalPerUSD?: number;
        redditThemes?: string[];
        affordability?: number; // allow precomputed affordability if you add it later
      }> = {};

      // Prefer live data; fall back to static if missing
      if (liveGdpMap[keyUpper] != null) {
        extra.gdpPerCapitaUsd = liveGdpMap[keyUpper];
      } else if (gdpMap[keyUpper] != null) {
        extra.gdpPerCapitaUsd = Number(gdpMap[keyUpper]);
      }

      if (liveFxMap[keyUpper] != null) {
        extra.fxLocalPerUSD = liveFxMap[keyUpper];
      } else if (fxMap[keyUpper] != null) {
        extra.fxLocalPerUSD = Number(fxMap[keyUpper]);
      }

      if (colMap[keyUpper] != null) {
        extra.costOfLivingIndex = Number(colMap[keyUpper]);
      }
      if (foodMap[keyUpper] != null) {
        extra.foodCostIndex = Number(foodMap[keyUpper]);
      } else if (colMap[keyUpper] != null) {
        extra.foodCostIndex = Number(colMap[keyUpper]);
      }
      if (housingMap[keyUpper] != null) {
        extra.housingCostIndex = Number(housingMap[keyUpper]);
      } else if (colMap[keyUpper] != null) {
        extra.housingCostIndex = Number(colMap[keyUpper]);
      }
      if (transportMap[keyUpper] != null) {
        extra.transportCostIndex = Number(transportMap[keyUpper]);
      } else if (colMap[keyUpper] != null) {
        extra.transportCostIndex = Number(colMap[keyUpper]);
      }
      if (themesMap[keyUpper]?.length) extra.redditThemes = themesMap[keyUpper];

      row.facts = facts ? { ...facts, ...extra } as CountryFacts : (extra as CountryFacts);

      try {
        const fxFacts = row.facts as unknown as FactsExtraServer;
        const { total } = buildRows(
          row.facts as CountryFacts,
          userWeights
        );
        fxFacts.scoreTotal = total;
      } catch {}


      // --- Compute daily spend (hotel traveler) from provider (preferred), fallback to estimator
      try {
        const fxFacts = row.facts as unknown as FactsExtraServer;
        const direct = costsByIso2.get(keyUpper);
        if (direct) {
          fxFacts.dailySpend = direct;
        } else {
          const spend = estimateDailySpendHotel({
            costOfLivingIndex: fxFacts.costOfLivingIndex,
            foodCostIndex: fxFacts.foodCostIndex,
            housingCostIndex: fxFacts.housingCostIndex,
            transportCostIndex: fxFacts.transportCostIndex,
            fxLocalPerUSD: fxFacts.fxLocalPerUSD,
            usdToLocalRate: fxFacts.usdToLocalRate,
            gdpPerCapitaUsd: fxFacts.gdpPerCapitaUsd,
          });
          if (spend) {
            fxFacts.dailySpend = spend;
          }
        }
      } catch {}

      // --- Attach Visa (US passport) ease & details
      try {
        const visa = visaIndex.get(keyUpper);
        if (visa) {
          const fxs = row.facts as unknown as FactsExtraServer;
          fxs.visaEase = visa.visaEase ?? undefined;
          fxs.visaType = visa.visaType;
          fxs.visaAllowedDays = visa.allowedDays;
          fxs.visaFeeUsd = visa.feeUsd;
          fxs.visaNotes = visa.notes;
          fxs.visaSource = visa.sourceUrl;
        }
      } catch {}

      // --- Attach seasonality: manual overrides only
      try {
        const fxFacts = row.facts as unknown as FactsExtraServer;
        const override: CountrySeasonalityDefinition | undefined =
          COUNTRY_SEASONALITY_DEFINITIONS[keyUpper];

        if (override && override.best && override.best.length) {
          const allMonths = Array.from(new Set(override.best)).sort((a, b) => a - b);
          const groups = clusterConsecutiveMonths(allMonths);
          const dualPeak = groups.length >= 2;

          const inBest = allMonths.includes(todayMonth);
          const inShoulder = override.shoulder?.includes(todayMonth) ?? false;
          const inGood = override.good?.includes(todayMonth) ?? false;
          const inAvoid = override.avoid?.includes(todayMonth) ?? false;

          let todayScore: number;
          if (inBest) todayScore = 100;           // peak season
          else if (inShoulder) todayScore = 80;   // shoulder season
          else if (inGood) todayScore = 40;       // "only good" season
          else if (inAvoid) todayScore = 0;       // avoid / low season
          else todayScore = 50;                   // neutral fallback when month is unclassified

          fxFacts.fmSeasonalityBestMonths = allMonths;
          fxFacts.fmSeasonalityShoulderMonths = override.shoulder ?? [];
          fxFacts.fmSeasonalityGoodMonths = override.good ?? [];
          fxFacts.fmSeasonalityAvoidMonths = override.avoid ?? [];
          fxFacts.fmSeasonalityAreas = fxFacts.fmSeasonalityAreas ?? [];
          fxFacts.fmSeasonalityHasDualPeak = dualPeak;
          fxFacts.fmSeasonalityTodayScore = todayScore;
          fxFacts.fmSeasonalityTodayLabel = fmTodayLabel(todayScore);
          fxFacts.fmSeasonalitySource = 'manual';
          fxFacts.fmSeasonalityNotes = override.notes;
          fxFacts.seasonality = todayScore;
        }
      } catch {}

      // --- Capture average daily cost (USD) for affordability bucketing
      try {
        const fxFacts = row.facts as unknown as FactsExtraServer;
        const avgCostUsd = extractAverageDailyCostUsd(fxFacts);
        if (avgCostUsd != null && Number.isFinite(avgCostUsd)) {
          fxFacts.averageDailyCostUsd = avgCostUsd;
        }
      } catch {}
    }

    // Helper: Generate affordability explanation from category and USD
    function affordabilityExplanationFromCategory(
      category: number,
      usd: number
    ): string {
      if (category <= 2) {
        return `Very low daily costs (≈ $${usd.toFixed(0)}/day). Strong value for accommodation, food, and transport compared to global averages.`;
      }
      if (category <= 4) {
        return `Generally affordable (≈ $${usd.toFixed(0)}/day). Costs are below Western Europe and North America averages.`;
      }
      if (category <= 6) {
        return `Moderate travel costs (≈ $${usd.toFixed(0)}/day). Expect typical mid-range international pricing.`;
      }
      if (category <= 8) {
        return `Higher daily costs (≈ $${usd.toFixed(0)}/day). Accommodation and dining are noticeably above global median levels.`;
      }
      return `Premium pricing (≈ $${usd.toFixed(0)}/day). Among the most expensive destinations globally for hotels and services.`;
    }
    // --- SECOND PASS: Absolute USD-based affordability buckets
    const USD_BUCKETS = [
      40,   // 1
      60,   // 2
      80,   // 3
      100,  // 4
      130,  // 5
      170,  // 6
      220,  // 7
      300,  // 8
      400   // 9
      // 10 = above 400
    ];

    for (const row of merged) {
      const fxFacts = row.facts as unknown as FactsExtraServer;
      const cost = fxFacts?.averageDailyCostUsd;

      if (typeof cost !== 'number' || !Number.isFinite(cost)) continue;

      let category = 10;

      for (let i = 0; i < USD_BUCKETS.length; i++) {
        if (cost <= USD_BUCKETS[i]) {
          category = i + 1;
          break;
        }
      }

      const score = (11 - category) * 10;

      fxFacts.affordabilityCategory = category;
      fxFacts.affordability = score;
      (fxFacts as FactsExtraServer & { affordabilityScore?: number }).affordabilityScore = score;
      fxFacts.affordabilityBand = affordabilityBandFromCategory(category);

      fxFacts.affordabilityExplanation =
        affordabilityExplanationFromCategory(category, cost);

      // Recompute total score after affordability injected
      try {
        const { total } = buildRows(
          row.facts as CountryFacts,
          userWeights
        );
        fxFacts.scoreTotal = total;
      } catch {}
    }

    if (userProfileLanguages.length) {
      try {
        const cookieStore = await cookies();
        const supabase = createServerClient(
          process.env.NEXT_PUBLIC_SUPABASE_URL!,
          process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
          {
            cookies: {
              get(name: string) {
                return cookieStore.get(name)?.value;
              },
            },
          }
        );

        const countryIso2s = merged.map((row) => row.iso2.toUpperCase());
        const { data: languageRows } = await supabase
          .from('country_language_profiles')
          .select('country_iso2,languages')
          .in('country_iso2', countryIso2s);

        const languageScoreByISO2 = new Map<string, number>();

        for (const languageRow of languageRows ?? []) {
          const countryISO2 = typeof languageRow.country_iso2 === 'string'
            ? languageRow.country_iso2.toUpperCase()
            : null;

          if (!countryISO2) continue;

          const score = computeLanguageCompatibilityScore(
            userProfileLanguages,
            languageRow.languages as CountryLanguageCoverage[] | null | undefined
          );

          if (score != null) {
            languageScoreByISO2.set(countryISO2, score);
          }
        }

        for (const row of merged) {
          const fxFacts = row.facts as FactsExtraServer | undefined;
          if (!fxFacts) continue;

          fxFacts.languageCompatibilityScore = languageScoreByISO2.get(row.iso2.toUpperCase());
        }
      } catch (err) {
        console.warn('[countries] failed to attach language compatibility', err);
      }
    }

    for (const row of merged) {
      try {
        const fxFacts = row.facts as FactsExtraServer | undefined;
        if (!fxFacts) continue;

        const { total } = buildRows(
          row.facts as CountryFacts,
          userWeights
        );
        fxFacts.scoreTotal = total;
      } catch {}
    }

    if (merged.length) {
      const s = merged[0];
      const sampleVisaEase = (s.facts ? (s.facts as FactsExtraServer).visaEase : undefined);
      console.log('[countries] sample', s.iso2, s.advisory?.level, sampleVisaEase);
    }
    console.log('[countries] attached live GDP+FX data');
  } catch (e) {
    console.warn('[countries] failed to attach facts:', e);
  }

  // Sort alphabetically by name
  merged.sort((x, y) => x.name.localeCompare(y.name));

  // Expose scoreTotal at top level for Discovery list
  const listPayload = merged.map((row) => ({
    ...row,
    scoreTotal: row.facts?.scoreTotal ?? 0,
  }));

  return NextResponse.json(listPayload);
}
