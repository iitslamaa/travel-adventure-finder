export type Country = {
  iso2: string;
  name: string;
  region?: string;
  subregion?: string;

  // Top-level score exposed by /api/countries
  scoreTotal?: number;

  // Advisory now lives at top-level from backend
  advisory?: {
    level?: number;
    score?: number;
    updatedAt?: string;
    url?: string;
    summary?: string;
  } | null;

  // Detail endpoint still returns facts
  facts?: {
    scoreTotal?: number;
    advisoryLevel?: number;
    seasonality?: number;
    visaEase?: number;
    affordability?: number;
    [key: string]: any;
  };

  [key: string]: any;
};