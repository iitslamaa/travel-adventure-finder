import type { CountryFacts, Weights } from './types';

export const DEFAULT_WEIGHTS: Weights = {
  advisorySafety: 0.30,
  soloFemale: 0.10,
  redditComposite: 0.20,
  seasonality: 0.05,
  visaEase: 0.05,
  affordability: 0.05,
  directFlight: 0.05,
  infrastructure: 0.05,
};

// Helper functions
const clamp = (x: number, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, x));
const advisoryToPct = (lvl?: 1 | 2 | 3 | 4) =>
  lvl ? clamp(((5 - lvl) / 4) * 100) : undefined;
const shrinkReddit = (score: number | undefined, n: number | undefined) => {
  if (score == null) return undefined;
  const k = (n ?? 0) >= 300 ? 1 : 0.7;
  return Math.round(k * score + (1 - k) * score);
};

// Compute final weighted score
export function computeScoreFromFacts(
  f: CountryFacts,
  w: Weights = DEFAULT_WEIGHTS
): number | null {
  const components: Array<{ value: number; weight: number }> = [];

  const advisory = advisoryToPct(f.advisoryLevel);
  if (advisory != null) components.push({ value: advisory, weight: w.advisorySafety });

  if (f.soloFemaleIndex != null)
    components.push({ value: f.soloFemaleIndex, weight: w.soloFemale });

  const reddit = shrinkReddit(f.redditComposite, f.redditN);
  if (reddit != null)
    components.push({ value: reddit, weight: w.redditComposite });

  if (f.seasonality != null)
    components.push({ value: f.seasonality, weight: w.seasonality });

  if (f.visaEase != null)
    components.push({ value: f.visaEase, weight: w.visaEase });

  if (f.affordability != null)
    components.push({ value: f.affordability, weight: w.affordability });

  if (f.directFlight != null)
    components.push({ value: f.directFlight, weight: w.directFlight });

  if (f.infrastructure != null)
    components.push({ value: f.infrastructure, weight: w.infrastructure });

  if (components.length === 0) return null;

  const totalWeight = components.reduce((sum, c) => sum + c.weight, 0);
  const weightedSum = components.reduce((sum, c) => sum + c.value * c.weight, 0);

  return Math.round(weightedSum / totalWeight);
}
