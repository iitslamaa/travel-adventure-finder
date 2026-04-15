export type Weights = {
  travelGov: number;
  seasonality: number;
  visaEase: number;
  affordability: number;
  language: number;
};

export type VisaEase =
  | 'freedom_of_movement'
  | 'visa_free'
  | 'eta'
  | 'voa'
  | 'visa_required'
  | 'unknown';

export type CountryFacts = {
  iso2: string;

  // Safety
  advisoryLevel?: 1 | 2 | 3 | 4;
  advisoryScore?: number;

  // Travel logistics
  seasonality?: number;
  visaEase?: number;
  affordability?: number;
  languageCompatibilityScore?: number;
  affordabilityCategory?: number; // 1 (cheapest) .. 10 (most expensive)
  affordabilityBand?: 'good' | 'warn' | 'bad' | 'danger';
  affordabilityExplanation?: string;
  averageDailyCostUsd?: number;
  dailySpend?: {
    totalUsd?: number;
    hotelUsd?: number;
    hostelUsd?: number;
    foodUsd?: number;
    transportUsd?: number;
    activitiesUsd?: number;
  };
  directFlight?: number;
  infrastructure?: number;

  // Meta
  advisoryUrl?: string;
  advisorySummary?: string;
  updatedAt?: string;
};
