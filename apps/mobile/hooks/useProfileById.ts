import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { getResizedAvatarUrl } from '../utils/avatar';

export type PublicProfile = {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;

  // optional fields (only render if present)
  languages?: any; // could be json
  travel_mode?: string | null;
  travel_style?: string | null;
  next_destination?: string | null;
  lived_countries?: string[] | null;
};

export function useProfileById(userId?: string | string[]) {
  const id = Array.isArray(userId) ? userId[0] : userId;

  const [profile, setProfile] = useState<PublicProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) return;

    async function run() {
      setLoading(true);

      const { data, error } = await supabase
        .from('profiles')
        .select(`
          id,
          username,
          full_name,
          avatar_url,
          languages,
          travel_mode,
          travel_style,
          next_destination,
          lived_countries
        `)
        .eq('id', id)
        .single();

      if (error) {
        console.error(error);
        setProfile(null);
      } else {
        const normalized = {
          ...data,
          avatar_url: getResizedAvatarUrl(data?.avatar_url ?? null),
          lived_countries: Array.isArray(data?.lived_countries)
            ? data.lived_countries
            : [],
        } as PublicProfile;

        setProfile(normalized);
      }

      setLoading(false);
    }

    run();
  }, [id]);

  return { profile, loading };
}