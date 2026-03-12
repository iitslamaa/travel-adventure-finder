// apps/web/app/api/country/[iso2]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { COUNTRY_SEEDS } from '@/lib/seed';
import { loadFacts } from '@/lib/facts';
import type { CountryFacts } from '@travel-af/shared';
import { buildVisaIndex } from '@/lib/providers/visa';
import { gdpPerCapitaUSDMap } from '@/lib/providers/worldbank';
import { fxLocalPerUSDMapByIso2 } from '@/lib/providers/fx';
import { estimateDailySpendHotel } from '@/lib/providers/costs';
import type { DailySpend } from '@/lib/providers/costs';
import { buildRows, DEFAULT_WEIGHTS } from '@travel-af/domain/src/scoring';
import { createServerClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';
import { headers } from 'next/headers';

import {
  COUNTRY_SEASONALITY_DEFINITIONS,
  type CountrySeasonalityDefinition,
} from '../../../../../../packages/data/src/countrySeasonality';

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
        .select('advisory, seasonality, visa, affordability')
        .eq('user_id', user.id)
        .maybeSingle();

      if (data) {
        const prefs = data as {
          advisory?: number;
          seasonality?: number;
          visa?: number;
          affordability?: number;
        };

        userWeights = {
          travelGov: prefs.advisory ?? DEFAULT_WEIGHTS.travelGov,
          seasonality: prefs.seasonality ?? DEFAULT_WEIGHTS.seasonality,
          visa: prefs.visa ?? DEFAULT_WEIGHTS.visa,
          affordability: prefs.affordability ?? DEFAULT_WEIGHTS.affordability,
        };
      }
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

  const facts = factsByIso2[isoUpper] as CountryFacts | undefined;

  const enriched: any = {
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
      const advisories = await advRes.json();
      const advisory = advisories.find((a: any) => a.iso2 === isoUpper);

      if (advisory?.level) {
        enriched.facts.advisoryLevel = advisory.level;

        // Compute normalized advisory score (0–100) same as scoring engine
        const advisoryScore = ((5 - advisory.level) / 4) * 100;
        enriched.facts.advisoryScore = advisoryScore;

        enriched.advisory = advisory;
      }
    }
  } catch (e) {
    console.warn('[country] advisory fetch failed', e);
  }

  const visa = visaIndex.get(isoUpper);
  if (visa) {
    enriched.facts = {
      ...enriched.facts,
      visaEase: visa.visaEase,
      visaType: visa.visaType,
      visaAllowedDays: visa.allowedDays,
      visaFeeUsd: visa.feeUsd,
      visaNotes: visa.notes,
      visaSource: visa.sourceUrl,
    };
  }

  if (gdpMap[isoUpper]) {
    enriched.facts.gdpPerCapitaUsd = gdpMap[isoUpper];
  }

  if (fxMap[isoUpper]) {
    enriched.facts.fxLocalPerUSD = fxMap[isoUpper];
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

      enriched.facts.seasonality = todayScore;
    }
  } catch {}

  // Compute daily spend (lightweight single-country version)
  try {
    const spend: DailySpend | undefined = estimateDailySpendHotel({
      costOfLivingIndex: enriched.facts.costOfLivingIndex,
      foodCostIndex: enriched.facts.foodCostIndex,
      housingCostIndex: enriched.facts.housingCostIndex,
      transportCostIndex: enriched.facts.transportCostIndex,
      fxLocalPerUSD: enriched.facts.fxLocalPerUSD,
      gdpPerCapitaUsd: enriched.facts.gdpPerCapitaUsd,
    });

    if (spend) {
      enriched.facts.dailySpend = spend;
    }
  } catch {}

  // --- Compute total score with user weights
  try {
    const { total } = buildRows(enriched.facts as CountryFacts, userWeights);
    enriched.scoreTotal = total;
  } catch {
    enriched.scoreTotal = 50;
  }

  return NextResponse.json(enriched);
}