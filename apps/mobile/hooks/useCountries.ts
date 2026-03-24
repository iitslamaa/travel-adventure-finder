import { useEffect, useMemo, useState } from 'react';
import { useScorePreferences } from '../context/ScorePreferencesContext';
import { Country } from '../types/Country';
import { applyScoreToCountry } from '../utils/scoring';

function iso2ToFlagEmoji(iso2?: string) {
  if (!iso2 || iso2.length !== 2) return undefined;
  return iso2
    .toUpperCase()
    .split('')
    .map(char => String.fromCodePoint(127397 + char.charCodeAt(0)))
    .join('');
}

export function useCountries() {
  const [rawCountries, setRawCountries] = useState<Country[]>([]);
  const [loading, setLoading] = useState(true);
  const { weights, selectedMonth } = useScorePreferences();

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
    () =>
      rawCountries.map(country =>
        applyScoreToCountry(country, weights, selectedMonth)
      ),
    [rawCountries, selectedMonth, weights]
  );

  return { countries, loading };
}
