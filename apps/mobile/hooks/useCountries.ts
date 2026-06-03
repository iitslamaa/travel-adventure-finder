import { useEffect, useMemo, useState } from 'react';
import { useScorePreferences } from '../context/ScorePreferencesContext';
import { useAuth } from '../context/AuthContext';
import { Country } from '../types/Country';
import { applyScoreToCountry } from '../utils/scoring';

type UseCountriesOptions = {
  excludeVisitedCountries?: boolean;
};

function iso2ToFlagEmoji(iso2?: string) {
  if (!iso2 || iso2.length !== 2) return undefined;
  return iso2
    .toUpperCase()
    .split('')
    .map(char => String.fromCodePoint(127397 + char.charCodeAt(0)))
    .join('');
}

export function useCountries(options: UseCountriesOptions = {}) {
  const [rawCountries, setRawCountries] = useState<Country[]>([]);
  const [loading, setLoading] = useState(true);
  const { weights, selectedMonth, excludeVisitedCountries } = useScorePreferences();
  const { visitedIsoCodes } = useAuth();

  useEffect(() => {
    const fetchCountries = async () => {
      try {
        const res = await fetch(
          'https://travel-scorer.vercel.app/api/countries',
          {
            headers: {
              Accept: 'application/json',
            },
          }
        );

        if (!res.ok) {
          throw new Error(`API error: ${res.status}`);
        }

        const data = await res.json();

        const mapped = Array.isArray(data)
          ? data.map((c: any) => ({
              ...c,
              iso2: c.iso2?.toUpperCase(),
              flagEmoji: iso2ToFlagEmoji(c.iso2?.toUpperCase()),
            }))
          : [];

        setRawCountries(mapped);
      } catch {
      } finally {
        setLoading(false);
      }
    };

    fetchCountries();
  }, []);

  const countries = useMemo(
    () => {
      const shouldExcludeVisited =
        options.excludeVisitedCountries && excludeVisitedCountries;
      const visitedSet = new Set(visitedIsoCodes.map(code => code.toUpperCase()));
      const baseCountries = shouldExcludeVisited
        ? rawCountries.filter(country => !visitedSet.has(country.iso2?.toUpperCase() ?? ''))
        : rawCountries;

      return baseCountries.map(country =>
        applyScoreToCountry(country, weights, selectedMonth)
      );
    },
    [
      excludeVisitedCountries,
      options.excludeVisitedCountries,
      rawCountries,
      selectedMonth,
      visitedIsoCodes,
      weights,
    ]
  );

  return { countries, loading };
}
