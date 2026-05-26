export type AffordabilityCostInputs = {
  costOfLivingIndex?: number | null;
  foodCostIndex?: number | null;
  housingCostIndex?: number | null;
  transportCostIndex?: number | null;
};

export type AffordabilityDailySpend = {
  foodUsd?: number;
  transportUsd?: number;
  activitiesUsd?: number;
  hotelUsd?: number;
  hostelUsd?: number;
  totalUsd?: number;
  basis?: {
    col?: number;
    food?: number;
    housing?: number;
    transport?: number;
  };
  source?: 'direct_cost_seed' | 'price_index_estimate';
  quality?: 'direct' | 'estimated';
  notes?: string[];
};

export type AffordabilityResult = {
  score: number;
  category: number;
  band: 'good' | 'warn' | 'bad' | 'danger';
  averageDailyCostUsd: number;
  dailySpend?: AffordabilityDailySpend;
  quality: 'direct' | 'estimated';
};

const BASE_FOOD_USD = 25;
const BASE_TRANSPORT_USD = 15;
const BASE_ACTIVITIES_USD = 15;
const BASE_HOTEL_USD = 70;
const BASE_DAILY_COST_USD =
  BASE_FOOD_USD + BASE_TRANSPORT_USD + BASE_ACTIVITIES_USD + BASE_HOTEL_USD;
const HOSTEL_TO_HOTEL_RATIO = 0.4;

const MIN_INDEX_SCALE = 0.4;
const MAX_INDEX_SCALE = 3;
const INDEX_BASELINE = 0.6;

export const AFFORDABILITY_MIN_DAILY_COST_USD = Math.round(
  BASE_DAILY_COST_USD * MIN_INDEX_SCALE
);
export const AFFORDABILITY_MAX_DAILY_COST_USD = Math.round(
  BASE_DAILY_COST_USD * MAX_INDEX_SCALE
);

export function clampScore(value: number): number {
  if (!Number.isFinite(value)) return 50;
  return Math.max(0, Math.min(100, Math.round(value)));
}

export function roundUsd(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.round(value));
}

function normalizedCostScale(index?: number | null): number {
  if (typeof index !== 'number' || !Number.isFinite(index)) return 1;

  const scale = index <= 3 ? index / INDEX_BASELINE : index / 100;
  return Math.min(MAX_INDEX_SCALE, Math.max(MIN_INDEX_SCALE, scale));
}

export function estimateDailySpendFromCostInputs(
  inputs: AffordabilityCostInputs
): AffordabilityDailySpend | undefined {
  const hasAnyIndex = [
    inputs.costOfLivingIndex,
    inputs.foodCostIndex,
    inputs.housingCostIndex,
    inputs.transportCostIndex,
  ].some((value) => typeof value === 'number' && Number.isFinite(value));

  if (!hasAnyIndex) return undefined;

  const col = inputs.costOfLivingIndex;
  const food = inputs.foodCostIndex;
  const housing = inputs.housingCostIndex;
  const transport = inputs.transportCostIndex;

  const colScale = normalizedCostScale(col);
  const foodScale = normalizedCostScale(food ?? col);
  const housingScale = normalizedCostScale(housing ?? col);
  const transportScale = normalizedCostScale(transport ?? col);

  const foodUsd = BASE_FOOD_USD * foodScale;
  const transportUsd = BASE_TRANSPORT_USD * transportScale;
  const activitiesUsd = BASE_ACTIVITIES_USD * colScale;
  const hotelUsd = BASE_HOTEL_USD * housingScale;

  return {
    foodUsd: roundUsd(foodUsd),
    transportUsd: roundUsd(transportUsd),
    activitiesUsd: roundUsd(activitiesUsd),
    hotelUsd: roundUsd(hotelUsd),
    hostelUsd: roundUsd(hotelUsd * HOSTEL_TO_HOTEL_RATIO),
    totalUsd: roundUsd(foodUsd + transportUsd + activitiesUsd + hotelUsd),
    basis: {
      col: typeof col === 'number' && Number.isFinite(col) ? col : undefined,
      food: typeof food === 'number' && Number.isFinite(food) ? food : undefined,
      housing: typeof housing === 'number' && Number.isFinite(housing) ? housing : undefined,
      transport: typeof transport === 'number' && Number.isFinite(transport) ? transport : undefined,
    },
    source: 'price_index_estimate',
    quality: 'estimated',
  };
}

export function dailyCostFromSpend(
  spend?: Pick<
    AffordabilityDailySpend,
    'totalUsd' | 'hotelUsd' | 'foodUsd' | 'transportUsd' | 'activitiesUsd'
  >
): number | undefined {
  if (!spend) return undefined;
  if (typeof spend.totalUsd === 'number' && Number.isFinite(spend.totalUsd)) {
    return spend.totalUsd;
  }

  const parts = [
    spend.hotelUsd,
    spend.foodUsd,
    spend.transportUsd,
    spend.activitiesUsd,
  ].filter((value): value is number => typeof value === 'number' && Number.isFinite(value));

  if (!parts.length) return undefined;
  return roundUsd(parts.reduce((sum, value) => sum + value, 0));
}

export function affordabilityScoreFromDailyCost(costUsd: number): number {
  if (!Number.isFinite(costUsd)) return 50;
  if (costUsd <= AFFORDABILITY_MIN_DAILY_COST_USD) return 100;
  if (costUsd >= AFFORDABILITY_MAX_DAILY_COST_USD) return 0;

  const minLog = Math.log(AFFORDABILITY_MIN_DAILY_COST_USD);
  const maxLog = Math.log(AFFORDABILITY_MAX_DAILY_COST_USD);
  const t = (Math.log(costUsd) - minLog) / (maxLog - minLog);

  return clampScore((1 - t) * 100);
}

export function affordabilityCategoryFromScore(score: number): number {
  const clamped = clampScore(score);
  if (clamped === 100) return 1;
  return Math.max(1, Math.min(10, Math.floor((100 - clamped) / 10) + 1));
}

export function affordabilityBandFromScore(
  score: number
): 'good' | 'warn' | 'bad' | 'danger' {
  const clamped = clampScore(score);
  if (clamped >= 70) return 'good';
  if (clamped >= 45) return 'warn';
  if (clamped >= 20) return 'bad';
  return 'danger';
}

export function computeAffordabilityFromDailySpend(
  spend: AffordabilityDailySpend
): AffordabilityResult | undefined {
  const averageDailyCostUsd = dailyCostFromSpend(spend);
  if (averageDailyCostUsd == null) return undefined;

  const score = affordabilityScoreFromDailyCost(averageDailyCostUsd);

  return {
    score,
    category: affordabilityCategoryFromScore(score),
    band: affordabilityBandFromScore(score),
    averageDailyCostUsd,
    dailySpend: spend,
    quality: spend.quality ?? 'estimated',
  };
}

export function computeAffordabilityFromCostInputs(
  inputs: AffordabilityCostInputs
): AffordabilityResult | undefined {
  const spend = estimateDailySpendFromCostInputs(inputs);
  return spend ? computeAffordabilityFromDailySpend(spend) : undefined;
}
