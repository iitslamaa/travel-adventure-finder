import { Country } from '../types/Country';
import type { ScoreWeights } from '../context/ScorePreferencesContext';
import { DEFAULT_SCORE_WEIGHTS } from '../context/ScorePreferencesContext';

function advisoryToScore(level?: number) {
  if (!level) return 50;
  return ((5 - level) / 4) * 100;
}

function uniqueMonthList(input: unknown): number[] {
  if (!Array.isArray(input)) return [];

  return Array.from(
    new Set(
      input
        .map(value => Number(value))
        .filter(value => Number.isFinite(value) && value >= 1 && value <= 12)
    )
  );
}

export function seasonalityScoreForMonth(country: Country, selectedMonth: number) {
  const month = selectedMonth;
  const bestMonths = uniqueMonthList(country.facts?.fmSeasonalityBestMonths);
  const shoulderMonths = uniqueMonthList(country.facts?.fmSeasonalityShoulderMonths);
  const goodMonths = uniqueMonthList(country.facts?.fmSeasonalityGoodMonths);
  const avoidMonths = uniqueMonthList(country.facts?.fmSeasonalityAvoidMonths);

  if (bestMonths.includes(month)) return 100;
  if (shoulderMonths.includes(month)) return 80;
  if (goodMonths.includes(month)) return 40;
  if (avoidMonths.includes(month)) return 0;

  if (typeof country.facts?.seasonality === 'number') {
    return country.facts.seasonality;
  }

  return typeof country.facts?.fmSeasonalityTodayScore === 'number'
    ? country.facts.fmSeasonalityTodayScore
    : 50;
}

function normalizeWeights(weights: ScoreWeights): ScoreWeights {
  const sum = Object.values(weights).reduce((total, value) => total + value, 0);
  if (!Number.isFinite(sum) || sum <= 0) {
    return DEFAULT_SCORE_WEIGHTS;
  }

  return {
    advisory: weights.advisory / sum,
    seasonality: weights.seasonality / sum,
    visa: weights.visa / sum,
    affordability: weights.affordability / sum,
    language: weights.language / sum,
  };
}

export function scoreCountry(
  country: Country,
  weights: ScoreWeights = DEFAULT_SCORE_WEIGHTS,
  selectedMonth = new Date().getMonth() + 1
) {
  const normalized = normalizeWeights(weights);
  const signals = [
    {
      key: 'advisory' as const,
      value:
        country.advisory?.score ??
        country.facts?.advisoryScore ??
        advisoryToScore(country.facts?.advisoryLevel),
    },
    {
      key: 'seasonality' as const,
      value: seasonalityScoreForMonth(country, selectedMonth),
    },
    {
      key: 'visa' as const,
      value: country.facts?.visaEase,
    },
    {
      key: 'affordability' as const,
      value: country.facts?.affordability,
    },
    {
      key: 'language' as const,
      value: country.facts?.languageCompatibilityScore,
    },
  ].filter(signal => Number.isFinite(signal.value));

  const presentWeightSum = signals.reduce(
    (sum, signal) => sum + normalized[signal.key],
    0
  );

  if (presentWeightSum <= 0) {
    return Math.round(country.scoreTotal ?? 0);
  }

  const total = signals.reduce((sum, signal) => {
    const weight = normalized[signal.key] / presentWeightSum;
    return sum + Number(signal.value) * weight;
  }, 0);

  return Math.round(total);
}

export function applyScoreToCountry(
  country: Country,
  weights: ScoreWeights,
  selectedMonth: number
): Country {
  return {
    ...country,
    scoreTotal: scoreCountry(country, weights, selectedMonth),
  };
}
