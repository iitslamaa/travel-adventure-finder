/**
 * Lightweight affordability helpers.
 * We estimate a daily spend for a hotel traveler by scaling global baselines
 * using country price indexes that already exist in our facts.
 *
 * Inputs are intentionally minimal to avoid importing large shared types here.
 */

import { DAILY_COSTS } from "@/data/sources/daily_costs";
import {
  estimateDailySpendFromCostInputs,
  roundUsd,
  type AffordabilityCostInputs,
  type AffordabilityDailySpend,
} from '@travel-af/domain/src/affordability';

export type CostInputs = AffordabilityCostInputs & {
  /** General cost-of-living price index where ~100 ~= global baseline */
  costOfLivingIndex?: number | null;
  /** Food-specific price index where ~100 ~= baseline */
  foodCostIndex?: number | null;
  /** Housing / lodging price index where ~100 ~= baseline */
  housingCostIndex?: number | null;
  /** Local transport price index where ~100 ~= baseline */
  transportCostIndex?: number | null;

  /** Local currency units per 1 USD (preferred) */
  fxLocalPerUSD?: number | null;
  /** Fallback: local currency units per 1 USD (same semantics as fxLocalPerUSD) */
  usdToLocalRate?: number | null;
  /** Optional: GDP per capita (USD) – currently unused, but kept for future tuning */
  gdpPerCapitaUsd?: number | null;
};

export type DailySpend = AffordabilityDailySpend;

/**
 * Estimate daily spend for a hotel traveler.
 * - Uses simple baselines (USD) that scale with price indices.
 * - foodCostIndex overrides costOfLivingIndex for food if present.
 * - If no indices are available, returns undefined so callers can hide the row.
 */
export function estimateDailySpendHotel(f: CostInputs): DailySpend | undefined {
  return estimateDailySpendFromCostInputs(f);
}

export async function buildCostIndex(): Promise<Map<string, DailySpend>> {
  const map = new Map<string, DailySpend>();

  for (const [iso2Raw, entry] of Object.entries(DAILY_COSTS)) {
    const iso2 = iso2Raw.toUpperCase();

    const foodUsd = roundUsd(entry.foodUsd);
    const transportUsd = roundUsd(entry.transportUsd);
    const activitiesUsd = roundUsd(entry.activitiesUsd);
    const hotelUsd = roundUsd(entry.hotelUsd);
    const hostelUsd = entry.hostelUsd != null
      ? roundUsd(entry.hostelUsd)
      : roundUsd(entry.hotelUsd * 0.4);

    const totalUsd = roundUsd(foodUsd + transportUsd + activitiesUsd + hotelUsd);

    map.set(iso2, {
      foodUsd,
      transportUsd,
      activitiesUsd,
      hotelUsd,
      hostelUsd,
      totalUsd,
      basis: {},
      source: "direct_cost_seed",
      quality: "direct",
      notes: ["Direct daily cost seed"],
    });
  }

  return map;
}
/**
 * Convenience formatter the UI can use if desired.
 * Example: "$84" (no decimals).
 */
export function fmtUsd(n?: number): string {
  if (typeof n !== 'number' || !isFinite(n)) return '—';
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(n);
}
