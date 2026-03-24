import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

export function useFriendCount(userId?: string | string[]) {
  const id = Array.isArray(userId) ? userId[0] : userId;

  const [count, setCount] = useState(0);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (!id) {
      setCount(0);
      setLoading(false);
      return;
    }

      setLoading(true);

      // fetch rows and count client-side (simple + reliable)
      const { data, error } = await supabase
        .from('friends')
        .select('user_id, friend_id')
        .or(`user_id.eq.${id},friend_id.eq.${id}`);

      if (error) {
        console.error(error);
        setCount(0);
      } else {
        const ids = (data ?? []).flatMap((row: any) => {
          if (row.user_id === id) return [row.friend_id];
          if (row.friend_id === id) return [row.user_id];
          return [];
        });
        setCount(new Set(ids.filter(Boolean)).size);
      }

      setLoading(false);
  }, [id]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { count, loading, refresh };
}
