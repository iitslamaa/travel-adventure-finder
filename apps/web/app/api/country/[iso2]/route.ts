// apps/web/app/api/country/[iso2]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { COUNTRY_SEEDS } from '@/lib/seed';
import { loadFacts } from '@/lib/facts';
import type { CountryFacts } from '@travel-af/shared';
import fs from 'node:fs/promises';
import path from 'node:path';
import { buildVisaIndex } from '@/lib/providers/visa';
import { gdpPerCapitaUSDMap } from '@/lib/providers/worldbank';
import { fxLocalPerUSDMapByIso2 } from '@/lib/providers/fx';
import { estimateDailySpendHotel } from '@/lib/providers/costs';
import { computeAffordabilityFromDailySpend } from '@travel-af/domain/src/affordability';
import { buildRows, DEFAULT_WEIGHTS } from '@travel-af/domain/src/scoring';
import { createServerClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';
import { headers } from 'next/headers';
import {
  computeLanguageCompatibilityScore,
  parseProfileLanguages,
  type CountryLanguageCoverage,
} from '@/lib/languageCompatibility';

import {
  COUNTRY_SEASONALITY_DEFINITIONS,
  type CountrySeasonalityDefinition,
} from '../../../../../../packages/data/src/countrySeasonality';

type CountryRouteFacts = Partial<CountryFacts> & {
  visaType?: string;
  visaAllowedDays?: number;
  visaFeeUsd?: number;
  visaNotes?: string;
  visaSource?: string;
  gdpPerCapitaUsd?: number;
  fxLocalPerUSD?: number;
  costOfLivingIndex?: number;
  foodCostIndex?: number;
  housingCostIndex?: number;
  transportCostIndex?: number;
  dailySpend?: CountryFacts['dailySpend'];
  averageDailyCostUsd?: number;
  affordabilityCategory?: number;
  affordability?: number;
  affordabilityBand?: 'good' | 'warn' | 'bad' | 'danger';
  affordabilityExplanation?: string;
  affordabilitySource?: 'direct_cost_seed' | 'price_index_estimate';
  affordabilityDataQuality?: 'direct' | 'estimated';
  fmSeasonalityBestMonths?: number[];
  fmSeasonalityShoulderMonths?: number[];
  fmSeasonalityGoodMonths?: number[];
  fmSeasonalityAvoidMonths?: number[];
  fmSeasonalityTodayScore?: number;
  fmSeasonalityTodayLabel?: 'best' | 'good' | 'shoulder' | 'poor';
  languageCompatibilityScore?: number;
};

async function safeJsonImport<T = Record<string, unknown>>(relativePath: string): Promise<T | null> {
  try {
    const fullPath = path.join(process.cwd(), relativePath);
    const raw = await fs.readFile(fullPath, 'utf8');
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

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

function clusterConsecutiveMonths(months: number[]): number[][] {
  if (!months.length) return [];
  const sorted = [...new Set(months.filter(m => m >= 1 && m <= 12))].sort((a, b) => a - b);
  const groups: number[][] = [];
  let group: number[] = [sorted[0]];
  for (let i = 1; i < sorted.length; i++) {
    if (sorted[i] === sorted[i - 1] + 1) group.push(sorted[i]);
    else { groups.push(group); group = [sorted[i]]; }
  }
  groups.push(group);
  const first = groups[0], last = groups[groups.length - 1];
  if (first && last && first[0] === 1 && last[last.length - 1] === 12) {
    groups[0] = [...last, ...first];
    groups.pop();
  }
  return groups;
}

export async function GET(
  _req: NextRequest,
  ctx: { params: Promise<{ iso2: string }> }
) {
  const { iso2 } = await ctx.params;
  const isoUpper = iso2.toUpperCase();

  const seed = COUNTRY_SEEDS.find(c => c.iso2.toUpperCase() === isoUpper);
  if (!seed) {
    return NextResponse.json({ error: 'Country not found' }, { status: 404 });
  }

  // --- Load user weights (same logic as list endpoint)
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

    const { data: { user } } = await supabase.auth.getUser();

    if (user) {
      const { data } = await supabase
        .from('user_score_preferences')
        .select('advisory, seasonality, visa, affordability, language')
        .eq('user_id', user.id)
        .maybeSingle();

      if (data) {
        const prefs = data as {
          advisory?: number;
          seasonality?: number;
          visa?: number;
          affordability?: number;
          language?: number;
        };

        userWeights = {
          travelGov: prefs.advisory ?? DEFAULT_WEIGHTS.travelGov,
          seasonality: prefs.seasonality ?? DEFAULT_WEIGHTS.seasonality,
          visa: prefs.visa ?? DEFAULT_WEIGHTS.visa,
          affordability: prefs.affordability ?? DEFAULT_WEIGHTS.affordability,
          language: prefs.language ?? DEFAULT_WEIGHTS.language,
        };
      }
    }
  } catch {}

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

    const { data: { user } } = await supabase.auth.getUser();

    if (user) {
      const { data } = await supabase
        .from('profiles')
        .select('languages')
        .eq('id', user.id)
        .maybeSingle();

      userProfileLanguages = parseProfileLanguages(data?.languages);
    }
  } catch {}

  // --- Heavy enrichment for ONE country only
  const isoList = [isoUpper];

  const factsByIso2 = await loadFacts(isoList, []);
  const visaIndex = await buildVisaIndex();
  const [gdpMap, fxMap] = await Promise.all([
    gdpPerCapitaUSDMap(isoList),
    fxLocalPerUSDMapByIso2(isoList),
  ]);
  const [
    colJson,
    foodJson,
    housingJson,
    transportJson,
  ] = await Promise.all([
    safeJsonImport<Record<string, number>>('data/sources/cost_of_living.json'),
    safeJsonImport<Record<string, number>>('data/sources/food_index.json'),
    safeJsonImport<Record<string, number>>('data/sources/housing_index.json'),
    safeJsonImport<Record<string, number>>('data/sources/transport_index.json'),
  ]);

  const facts = factsByIso2[isoUpper] as CountryFacts | undefined;

  const enriched: typeof seed & {
    facts: CountryRouteFacts;
    advisory?: { iso2?: string; level?: number };
    scoreTotal?: number;
  } = {
    ...seed,
    facts: facts ?? {},
  };

  // --- Fetch and attach advisory for this country
  try {
    const h = await headers();
    const host = h.get('host');
    const proto = h.get('x-forwarded-proto') ?? 'https';
    const base = host ? `${proto}://${host}` : '';

    const advUrl = base ? `${base}/api/advisories` : '/api/advisories';
    const advRes = await fetch(advUrl, { cache: 'no-store' });

    if (advRes.ok) {
      const advisories = (await advRes.json()) as Array<{
        iso2?: string;
        level?: 1 | 2 | 3 | 4;
      }>;
      const advisory = advisories.find((a) => a.iso2 === isoUpper);

      if (advisory?.level) {
        const advisoryLevel = advisory.level;
        enriched.facts.advisoryLevel = advisoryLevel;

        // Compute normalized advisory score (0–100) same as scoring engine
        const advisoryScore = ((5 - advisoryLevel) / 4) * 100;
        enriched.facts.advisoryScore = advisoryScore;

        enriched.advisory = { iso2: advisory.iso2, level: advisoryLevel };
      }
    }
  } catch (e) {
    console.warn('[country] advisory fetch failed', e);
  }

  const visa = visaIndex.get(isoUpper);
  if (visa) {
    enriched.facts = {
      ...enriched.facts,
      visaEase: visa.visaEase ?? undefined,
      visaType: visa.visaType ?? undefined,
      visaAllowedDays: visa.allowedDays ?? undefined,
      visaFeeUsd: visa.feeUsd ?? undefined,
      visaNotes: visa.notes ?? undefined,
      visaSource: visa.sourceUrl ?? undefined,
    };
  }

  if (gdpMap[isoUpper]) {
    enriched.facts.gdpPerCapitaUsd = gdpMap[isoUpper];
  }

  if (fxMap[isoUpper]) {
    enriched.facts.fxLocalPerUSD = fxMap[isoUpper];
  }

  if (colJson?.[isoUpper] != null) {
    enriched.facts.costOfLivingIndex = Number(colJson[isoUpper]);
  }
  if (foodJson?.[isoUpper] != null) {
    enriched.facts.foodCostIndex = Number(foodJson[isoUpper]);
  } else if (colJson?.[isoUpper] != null) {
    enriched.facts.foodCostIndex = Number(colJson[isoUpper]);
  }
  if (housingJson?.[isoUpper] != null) {
    enriched.facts.housingCostIndex = Number(housingJson[isoUpper]);
  } else if (colJson?.[isoUpper] != null) {
    enriched.facts.housingCostIndex = Number(colJson[isoUpper]);
  }
  if (transportJson?.[isoUpper] != null) {
    enriched.facts.transportCostIndex = Number(transportJson[isoUpper]);
  } else if (colJson?.[isoUpper] != null) {
    enriched.facts.transportCostIndex = Number(colJson[isoUpper]);
  }

  // --- Attach seasonality using same FM override logic as list endpoint
  try {
    const todayMonth = new Date().getMonth() + 1;

    const override: CountrySeasonalityDefinition | undefined =
      COUNTRY_SEASONALITY_DEFINITIONS[isoUpper];

    if (override && override.best && override.best.length) {
      const allMonths = Array.from(new Set(override.best)).sort((a, b) => a - b);
      clusterConsecutiveMonths(allMonths); // preserve identical logic path

      const inBest = allMonths.includes(todayMonth);
      const inShoulder = override.shoulder?.includes(todayMonth) ?? false;
      const inGood = override.good?.includes(todayMonth) ?? false;
      const inAvoid = override.avoid?.includes(todayMonth) ?? false;

      let todayScore: number;

      if (inBest) todayScore = 100;
      else if (inShoulder) todayScore = 80;
      else if (inGood) todayScore = 40;
      else if (inAvoid) todayScore = 0;
      else todayScore = 50;

      enriched.facts.fmSeasonalityBestMonths = allMonths;
      enriched.facts.fmSeasonalityShoulderMonths = override.shoulder ?? [];
      enriched.facts.fmSeasonalityGoodMonths = override.good ?? [];
      enriched.facts.fmSeasonalityAvoidMonths = override.avoid ?? [];
      enriched.facts.fmSeasonalityTodayScore = todayScore;
      enriched.facts.fmSeasonalityTodayLabel =
        inBest ? 'best' :
        inShoulder ? 'shoulder' :
        inGood ? 'good' :
        inAvoid ? 'poor' :
        'shoulder';

      enriched.facts.seasonality = todayScore;
    }
  } catch {}

  // Compute daily spend (lightweight single-country version)
  try {
    const spend = estimateDailySpendHotel({
      costOfLivingIndex: enriched.facts.costOfLivingIndex,
      foodCostIndex: enriched.facts.foodCostIndex,
      housingCostIndex: enriched.facts.housingCostIndex,
      transportCostIndex: enriched.facts.transportCostIndex,
      fxLocalPerUSD: enriched.facts.fxLocalPerUSD,
      gdpPerCapitaUsd: enriched.facts.gdpPerCapitaUsd,
    });

    if (spend) {
      enriched.facts.dailySpend = spend;
      const affordability = computeAffordabilityFromDailySpend(spend);

      if (affordability) {
        enriched.facts.averageDailyCostUsd = affordability.averageDailyCostUsd;
        enriched.facts.affordabilityCategory = affordability.category;
        enriched.facts.affordability = affordability.score;
        enriched.facts.affordabilityBand = affordability.band;
        enriched.facts.affordabilitySource =
          affordability.dailySpend?.source ?? 'price_index_estimate';
        enriched.facts.affordabilityDataQuality = affordability.quality;
        enriched.facts.affordabilityExplanation = affordabilityExplanationFromCategory(
          affordability.category,
          affordability.averageDailyCostUsd
        );
      }
    }
  } catch {}

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

      const { data } = await supabase
        .from('country_language_profiles')
        .select('languages')
        .eq('country_iso2', isoUpper)
        .maybeSingle();

      enriched.facts.languageCompatibilityScore = computeLanguageCompatibilityScore(
        userProfileLanguages,
        data?.languages as CountryLanguageCoverage[] | null | undefined
      );
    } catch {}
  }

  // --- Compute total score with user weights
  try {
    const { total } = buildRows(enriched.facts as CountryFacts, userWeights);
    enriched.scoreTotal = total;
  } catch {
    enriched.scoreTotal = 50;
  }

  return NextResponse.json(enriched);
}
