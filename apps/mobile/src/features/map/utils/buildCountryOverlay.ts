import { CountryFeatureOverlay } from '../types/map.types';

type OverlayParams = {
  iso: string;
  selectedIso?: string;
  score?: number;
  highlightedIsos?: string[];
};

export function buildCountryOverlay({
  iso,
  selectedIso,
  score,
  highlightedIsos,
}: OverlayParams): CountryFeatureOverlay {
  const isSelected = selectedIso === iso;

  // Selected country (bold, gold highlight)
  if (isSelected) {
    return {
      iso,
      strokeColor: '#000000',
      fillColor: 'rgba(255, 215, 0, 0.65)',
    };
  }

  const isHighlighted = highlightedIsos?.includes(iso);

  if (!isSelected && isHighlighted) {
    return {
      iso,
      strokeColor: 'transparent',
      fillColor: 'rgba(255, 215, 0, 0.35)',
    };
  }

  // Score-based coloring (used in detailed/full dataset mode)
  if (typeof score === 'number') {
    if (score >= 80) {
      return {
        iso,
        strokeColor: 'transparent',
        fillColor: 'rgba(34, 197, 94, 0.5)',
      };
    }

    if (score >= 60) {
      return {
        iso,
        strokeColor: 'transparent',
        fillColor: 'rgba(234, 179, 8, 0.5)',
      };
    }

    if (score >= 40) {
      return {
        iso,
        strokeColor: 'transparent',
        fillColor: 'rgba(249, 115, 22, 0.5)',
      };
    }

    return {
      iso,
      strokeColor: 'transparent',
      fillColor: 'rgba(239, 68, 68, 0.5)',
    };
  }

  // World idle state (simplified dataset)
  return {
    iso,
    strokeColor: 'transparent',
    fillColor: 'rgba(0, 0, 0, 0)', // transparent fill for clean world outline
  };
}