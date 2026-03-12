import { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

export function useFriendshipStatus(viewedUserId?: string | string[]) {
  const { session } = useAuth();
  const viewerId = session?.user?.id;
  const targetId = Array.isArray(viewedUserId) ? viewedUserId[0] : viewedUserId;

  const [isFriend, setIsFriend] = useState(false);
  const [isPending, setIsPending] = useState(false);
  const [loading, setLoading] = useState(true);

  const runCheck = useCallback(async () => {
    if (!viewerId || !targetId) return;

    setLoading(true);

    // Check friendship
    const { data: friendData, error: friendError } = await supabase
      .from('friends')
      .select('id')
      .or(
        `and(user_id.eq.${viewerId},friend_id.eq.${targetId}),and(user_id.eq.${targetId},friend_id.eq.${viewerId})`
      )
      .limit(1);

    if (friendError) {
      console.error(friendError);
      setIsFriend(false);
    } else {
      setIsFriend((friendData?.length ?? 0) > 0);
    }

    // Check pending request (viewer -> target)
    const { data: pendingData, error: pendingError } = await supabase
      .from('friend_requests')
      .select('id')
      .eq('sender_id', viewerId)
      .eq('receiver_id', targetId)
      .eq('status', 'pending')
      .limit(1);

    if (pendingError) {
      console.error(pendingError);
      setIsPending(false);
    } else {
      setIsPending((pendingData?.length ?? 0) > 0);
    }

    setLoading(false);
  }, [viewerId, targetId]);

  useEffect(() => {
    runCheck();
  }, [runCheck]);

  return {
    isFriend,
    isPending,
    loading,
    refresh: runCheck,
  };
}