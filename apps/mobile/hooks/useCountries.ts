import { useEffect, useState } from 'react';
import { Country } from '../types/Country';

function iso2ToFlagEmoji(iso2?: string) {
  if (!iso2 || iso2.length !== 2) return undefined;
  return iso2
    .toUpperCase()
    .split('')
    .map(char => String.fromCodePoint(127397 + char.charCodeAt(0)))
    .join('');
}

export function useCountries() {
  const [countries, setCountries] = useState<Country[]>([]);
  const [loading, setLoading] = useState(true);

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
          const errorText = await res.text();
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

        setCountries(mapped);
      } catch (error) {
      } finally {
        setLoading(false);
      }
    };

    fetchCountries();
  }, []);

  return { countries, loading };
}