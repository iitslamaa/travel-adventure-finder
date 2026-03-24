import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { getResizedAvatarUrl } from '../utils/avatar';

type EngagementProfile = {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  lived_countries?: string[] | null;
};

type CountryFriendEngagement = {
  totalFriends: number;
  visited: EngagementProfile[];
  bucketList: EngagementProfile[];
  fromHere: EngagementProfile[];
};

const EMPTY_ENGAGEMENT: CountryFriendEngagement = {
  totalFriends: 0,
  visited: [],
  bucketList: [],
  fromHere: [],
};

function sortProfiles(profiles: EngagementProfile[]) {
  return [...profiles].sort((lhs, rhs) => {
    const lhsName = (lhs.full_name || '').trim();
    const rhsName = (rhs.full_name || '').trim();

    if (!lhsName || !rhsName) {
      return (lhs.username || '').localeCompare(rhs.username || '');
    }

    return lhsName.localeCompare(rhsName);
  });
}

export function useCountryFriendEngagement(countryCode?: string) {
  const { session } = useAuth();
  const [engagement, setEngagement] = useState<CountryFriendEngagement>(EMPTY_ENGAGEMENT);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const userId = session?.user?.id;
    const normalizedCountryCode = countryCode?.trim().toUpperCase();

    if (!userId || !normalizedCountryCode) {
      setEngagement(EMPTY_ENGAGEMENT);
      setLoading(false);
      return;
    }

    let cancelled = false;

    const fetchEngagement = async () => {
      setLoading(true);

      const { data: friendRows, error: friendError } = await supabase
        .from('friends')
        .select('user_id, friend_id')
        .or(`user_id.eq.${userId},friend_id.eq.${userId}`);

      if (friendError) {
        console.error('Country engagement friends error', friendError);
        if (!cancelled) {
          setEngagement(EMPTY_ENGAGEMENT);
          setLoading(false);
        }
        return;
      }

      const friendIds = Array.from(
        new Set(
          (friendRows ?? []).flatMap((row: { user_id: string; friend_id: string }) => {
            if (row.user_id === userId) return [row.friend_id];
            if (row.friend_id === userId) return [row.user_id];
            return [];
          })
        )
      ).filter(Boolean);

      if (!friendIds.length) {
        if (!cancelled) {
          setEngagement(EMPTY_ENGAGEMENT);
          setLoading(false);
        }
        return;
      }

      const [profilesRes, visitedRes, bucketRes] = await Promise.all([
        supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, lived_countries')
          .in('id', friendIds),
        supabase
          .from('user_traveled')
          .select('user_id')
          .eq('country_id', normalizedCountryCode)
          .in('user_id', friendIds),
        supabase
          .from('user_bucket_list')
          .select('user_id')
          .eq('country_id', normalizedCountryCode)
          .in('user_id', friendIds),
      ]);

      if (profilesRes.error) {
        console.error('Country engagement profiles error', profilesRes.error);
      }
      if (visitedRes.error) {
        console.error('Country engagement visited error', visitedRes.error);
      }
      if (bucketRes.error) {
        console.error('Country engagement bucket error', bucketRes.error);
      }

      const profiles = ((profilesRes.data ?? []) as EngagementProfile[]).map(profile => ({
        ...profile,
        avatar_url: getResizedAvatarUrl(profile.avatar_url),
      }));

      const profileById = new Map(profiles.map(profile => [profile.id, profile] as const));
      const visitedIds = new Set((visitedRes.data ?? []).map((row: { user_id: string }) => row.user_id));
      const bucketIds = new Set((bucketRes.data ?? []).map((row: { user_id: string }) => row.user_id));

      const fromHere = profiles.filter(profile =>
        (profile.lived_countries ?? []).some(
          livedCountry => livedCountry.trim().toUpperCase() === normalizedCountryCode
        )
      );

      if (!cancelled) {
        setEngagement({
          totalFriends: profiles.length,
          visited: sortProfiles(
            Array.from(visitedIds).map(id => profileById.get(id)).filter(Boolean) as EngagementProfile[]
          ),
          bucketList: sortProfiles(
            Array.from(bucketIds).map(id => profileById.get(id)).filter(Boolean) as EngagementProfile[]
          ),
          fromHere: sortProfiles(fromHere),
        });
        setLoading(false);
      }
    };

    fetchEngagement();

    return () => {
      cancelled = true;
    };
  }, [countryCode, session?.user?.id]);

  return { engagement, loading };
}
