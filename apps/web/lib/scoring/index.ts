import { advisoryScore } from './advisoryScore';
import { affordabilityScore, type AffordabilityInput } from './affordabilityScore';
import { visaScore } from './visaScore';

// Facts the scorer depends on (plus affordability inputs via intersection)
export type FactsForScoring = (
  Partial<{
    advisoryLevel: 1 | 2 | 3 | 4;
    visaEase: number;               // 0..100
    redditComposite: number;        // 0..100
    seasonality: number;            // 0..100
    infrastructure: number;         // 0..100
  }>
) & AffordabilityInput;

// Weights for each factor. Sum ~= 1.0
export const WEIGHTS = {
  advisory: 0.30,
  affordability: 0.20,
  visa: 0.10,
  reddit: 0.20,
  seasonality: 0.05,
  infrastructure: 0.05,
} as const;

export type FactorKey = keyof typeof WEIGHTS; // "advisory" | "affordability" | ...
export type ScoreBreakdown = Record<FactorKey, number>;

function safeNumber(n: unknown, fallback = 50): number {
  const v = Number(n);
  return Number.isFinite(v) ? v : fallback;
}

export function computeCountryScore(
  facts: FactsForScoring = {} as FactsForScoring
): { total: number; scores: ScoreBreakdown } {
  const scores: ScoreBreakdown = {
    advisory: advisoryScore(facts.advisoryLevel),
    affordability: affordabilityScore(facts as AffordabilityInput),
    visa: visaScore(typeof facts.visaEase === 'number' ? facts.visaEase : undefined),
    reddit: safeNumber(facts.redditComposite),
    seasonality: safeNumber(facts.seasonality),
    infrastructure: safeNumber(facts.infrastructure),
  };

  // Weighted total (no renormalization required; safeNumber provides neutral defaults)
  const total = (Object.keys(WEIGHTS) as FactorKey[])
    .reduce((sum, key) => sum + scores[key] * WEIGHTS[key], 0);

  return { total: Math.round(total), scores };
}
