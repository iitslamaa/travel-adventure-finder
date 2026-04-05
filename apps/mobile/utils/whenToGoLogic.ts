import { Country } from '../types/Country';

export type WhenToGoItem = {
  id: string;
  country: Country;
};

function normalizeMonth(m: number) {
  // API uses 1-12
  return m - 1; // convert to 0-11
}

function getShoulderMonths(bestMonths: number[]) {
  const shoulders = new Set<number>();

  bestMonths.forEach(m => {
    const zero = normalizeMonth(m);

    const before = (zero - 1 + 12) % 12;
    const after = (zero + 1) % 12;

    shoulders.add(before);
    shoulders.add(after);
  });

  return shoulders;
}

export function getWhenToGoBuckets(
  countries: Country[],
  selectedMonth: number
) {
  const peak: WhenToGoItem[] = [];
  const good: WhenToGoItem[] = [];
  const shoulder: WhenToGoItem[] = [];
  const rough: WhenToGoItem[] = [];

  countries.forEach(c => {
    const bestMonths: number[] =
      c.facts?.fmSeasonalityBestMonths ?? [];

    if (!bestMonths.length) return;

    const normalizedBest = bestMonths.map(normalizeMonth);
    const shoulderMonths = getShoulderMonths(bestMonths);

    const selectedMonth0 = normalizeMonth(selectedMonth);
    const isPeak = normalizedBest.includes(selectedMonth0);
    const isShoulder =
      shoulderMonths.has(selectedMonth0) &&
      !isPeak;

    if (isPeak) {
      peak.push({
        id: c.iso2,
        country: c,
      });
    } else if (isShoulder) {
      shoulder.push({
        id: c.iso2,
        country: c,
      });
    } else {
      const overallScore = c.facts?.scoreTotal ?? 0;
      const target = overallScore >= 65 ? good : rough;
      target.push({
        id: c.iso2,
        country: c,
      });
    }
  });

  // Sort by real scoreTotal descending
  peak.sort((a, b) => (b.country.facts?.scoreTotal ?? 0) - (a.country.facts?.scoreTotal ?? 0));
  good.sort((a, b) => (b.country.facts?.scoreTotal ?? 0) - (a.country.facts?.scoreTotal ?? 0));
  shoulder.sort((a, b) => (b.country.facts?.scoreTotal ?? 0) - (a.country.facts?.scoreTotal ?? 0));
  rough.sort((a, b) => (b.country.facts?.scoreTotal ?? 0) - (a.country.facts?.scoreTotal ?? 0));

  return { peak, good, shoulder, rough };
}
