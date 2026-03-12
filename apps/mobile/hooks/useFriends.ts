import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { getResizedAvatarUrl } from '../utils/avatar';

export type FriendProfile = {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
};

export function useFriends(targetUserId?: string) {
  const { session } = useAuth();
  const user = session?.user;
  const effectiveUserId = targetUserId ?? user?.id;
  const [friends, setFriends] = useState<FriendProfile[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchFriends = async () => {
    if (!effectiveUserId) return;
    const userId = effectiveUserId;

    setLoading(true);

    const { data: friendRows, error: friendError } = await supabase
      .from('friends')
      .select('user_id, friend_id')
      .or(`user_id.eq.${userId},friend_id.eq.${userId}`);

    if (friendError) {
      console.error(friendError);
      setLoading(false);
      return;
    }

    const ids = (friendRows ?? []).flatMap((row: any) => {
      if (row.user_id === userId) return [row.friend_id];
      if (row.friend_id === userId) return [row.user_id];
      return [];
    });

    const friendIds = Array.from(new Set(ids)).filter(Boolean);

    if (friendIds.length === 0) {
      setFriends([]);
      setLoading(false);
      return;
    }

    const { data: profiles, error: profileError } = await supabase
      .from('profiles')
      .select('id, username, full_name, avatar_url')
      .in('id', friendIds);

    if (profileError) {
      console.error(profileError);
    } else {
      const typedProfiles = (profiles as FriendProfile[]) ?? [];

      const normalizedProfiles = typedProfiles.map((p) => ({
        ...p,
        avatar_url: getResizedAvatarUrl(p.avatar_url),
      }));

      const sorted = normalizedProfiles.sort((a, b) =>
        (a.full_name ?? '').localeCompare(b.full_name ?? '')
      );

      setFriends(sorted);
    }

    setLoading(false);
  };

  const refresh = async () => {
    if (!effectiveUserId) return;
    await fetchFriends();
  };

  useEffect(() => {
    fetchFriends();
  }, [effectiveUserId]);

  return { friends, loading, refresh };
}