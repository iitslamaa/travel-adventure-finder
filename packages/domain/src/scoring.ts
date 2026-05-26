// packages/domain/src/scoring.ts

import type { CountryFacts } from '@travel-af/shared';
import {
  computeAffordabilityFromCostInputs,
  computeAffordabilityFromDailySpend,
} from './affordability';

// --- Weights (sum = 1.0)
export const W = {
  travelGov: 0.35,
  seasonality: 0.15,
  visa: 0.15,
  affordability: 0.15,
  language: 0.20,
} as const;

export const DEFAULT_WEIGHTS: ScoreWeights = { ...W };

export function normalizeWeights(
  partial: Partial<ScoreWeights>
): ScoreWeights {
  const merged: ScoreWeights = { ...DEFAULT_WEIGHTS, ...partial };

  const sum = Object.values(merged).reduce(
    (a, b) => a + (Number(b) || 0),
    0
  );

  if (!Number.isFinite(sum) || sum <= 0) {
    return { ...DEFAULT_WEIGHTS };
  }

  return {
    travelGov: merged.travelGov / sum,
    seasonality: merged.seasonality / sum,
    visa: merged.visa / sum,
    affordability: merged.affordability / sum,
    language: merged.language / sum,
  };
}

export type ScoreWeights = {
  [K in keyof typeof W]: number;
};

export type FactRow = {
  key: keyof typeof W;
  label: string;
  raw?: number;   // 0..100
  weight: number; // original weight (0..1)
  contrib: number; // raw * (weight / sumPresentWeights)
};

// --- Internal helpers (pure math only)

function toNumber(x: unknown): number | undefined {
  const n = Number(x);
  return Number.isFinite(n) ? n : undefined;
}

// --- Affordability derivation (pure scoring logic only)

type FactsExtra = CountryFacts & {
  costOfLivingIndex?: number;
  foodCostIndex?: number;
  gdpPerCapitaUsd?: number;
  fxLocalPerUSD?: number;
  localPerUSD?: number;
  usdToLocalRate?: number;
  housingCostIndex?: number;
  transportCostIndex?: number;
  dailySpend?: CountryFacts['dailySpend'];
  affordability?: number;
  languageCompatibilityScore?: number;
};

export function computeAffordability(
  facts: FactsExtra
): number | undefined {
  const dailySpend = facts.dailySpend
    ? computeAffordabilityFromDailySpend(facts.dailySpend)
    : undefined;
  if (dailySpend) return dailySpend.score;

  const estimated = computeAffordabilityFromCostInputs({
    costOfLivingIndex: toNumber(facts.costOfLivingIndex),
    foodCostIndex: toNumber(facts.foodCostIndex),
    housingCostIndex: toNumber(facts.housingCostIndex),
    transportCostIndex: toNumber(facts.transportCostIndex),
  });

  return estimated?.score ?? 50;
}

// --- Advisory mapping

function advisoryToScore(level?: 1 | 2 | 3 | 4) {
  if (!level) return 50;
  return ((5 - level) / 4) * 100;
}

// --- Main scoring engine

export function buildRows(
  facts: CountryFacts,
  weights: Partial<ScoreWeights> = DEFAULT_WEIGHTS
): { rows: FactRow[]; total: number } {
  const fx = facts as FactsExtra;

  const normalizedWeights = normalizeWeights(weights);

  const signals: {
    key: FactRow['key'];
    label: string;
    value?: number;
  }[] = [
    {
      key: 'travelGov',
      label: 'Travel.gov advisory',
      value: advisoryToScore(facts.advisoryLevel),
    },
    {
      key: 'seasonality',
      label: 'Seasonality (now)',
      value: facts.seasonality,
    },
    {
      key: 'visa',
      label: 'Visa ease (US passport)',
      value: facts.visaEase,
    },
    {
      key: 'affordability',
      label: 'Affordability',
      value:
        fx.affordability ??
        computeAffordability(fx),
    },
    {
      key: 'language',
      label: 'Language compatibility',
      value: facts.languageCompatibilityScore,
    },
  ];

  // Only count weights for present signals
  const presentWeightSum = signals
    .filter((s) => Number.isFinite(s.value))
    .reduce(
      (acc, s) =>
        acc + normalizedWeights[s.key],
      0
    );

  const rows: FactRow[] = signals.map((s) => {
    const raw = Number.isFinite(s.value as number)
      ? (s.value as number)
      : undefined;

    const w = normalizedWeights[s.key];
    const effW = presentWeightSum > 0 ? w / presentWeightSum : 0;

    const contrib = raw != null ? raw * effW : 0;

    return {
      key: s.key,
      label: s.label,
      raw,
      weight: w,
      contrib,
    };
  });

  const total = Math.round(
    rows.reduce((a, r) => a + r.contrib, 0)
  );

  return { rows, total };
}
