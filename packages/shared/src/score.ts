import type { CountryFacts, Weights } from './types';

export const DEFAULT_WEIGHTS: Weights = {
  travelGov: 0.35,
  seasonality: 0.15,
  visaEase: 0.15,
  affordability: 0.15,
  language: 0.20,
};

// Helper functions
const clamp = (x: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, x));
const advisoryToPct = (lvl?: 1 | 2 | 3 | 4) =>
  lvl ? clamp(((5 - lvl) / 4) * 100) : undefined;

// Compute final weighted score
export function computeScoreFromFacts(
  f: CountryFacts,
  w: Weights = DEFAULT_WEIGHTS
): number | null {
  const components: Array<{ value: number; weight: number }> = [];

  const advisory = advisoryToPct(f.advisoryLevel);
  if (advisory != null) components.push({ value: advisory, weight: w.travelGov });

  if (f.seasonality != null)
    components.push({ value: f.seasonality, weight: w.seasonality });

  if (f.visaEase != null)
    components.push({ value: f.visaEase, weight: w.visaEase });

  if (f.affordability != null)
    components.push({ value: f.affordability, weight: w.affordability });

  if (f.languageCompatibilityScore != null)
    components.push({ value: f.languageCompatibilityScore, weight: w.language });

  if (components.length === 0) return null;

  const totalWeight = components.reduce((sum, c) => sum + c.weight, 0);
  const weightedSum = components.reduce((sum, c) => sum + c.value * c.weight, 0);

  return Math.round(weightedSum / totalWeight);
}
