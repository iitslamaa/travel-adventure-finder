import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

export function useUserCounts(userId?: string | string[]) {
  const id = Array.isArray(userId) ? userId[0] : userId;

  const [traveledCount, setTraveledCount] = useState(0);
  const [bucketCount, setBucketCount] = useState(0);
  const [loading, setLoading] = useState(true);

  const [traveledIsoCodes, setTraveledIsoCodes] = useState<string[]>([]);
  const [bucketIsoCodes, setBucketIsoCodes] = useState<string[]>([]);

  const refresh = useCallback(async () => {
    if (!id) {
      setTraveledCount(0);
      setBucketCount(0);
      setTraveledIsoCodes([]);
      setBucketIsoCodes([]);
      setLoading(false);
      return;
    }

      setLoading(true);

      const [
        traveledRes,
        bucketRes,
      ] = await Promise.all([
        supabase
          .from('user_traveled')
          .select('country_id', { count: 'exact' })
          .eq('user_id', id),

        supabase
          .from('user_bucket_list')
          .select('country_id', { count: 'exact' })
          .eq('user_id', id),
      ]);

      if (traveledRes.error) console.error(traveledRes.error);
      if (bucketRes.error) console.error(bucketRes.error);

      setTraveledCount(traveledRes.count ?? 0);
      setBucketCount(bucketRes.count ?? 0);

      setTraveledIsoCodes(
        traveledRes.data?.map((r: any) => r.country_id) ?? []
      );

      setBucketIsoCodes(
        bucketRes.data?.map((r: any) => r.country_id) ?? []
      );

      setLoading(false);
  }, [id]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return {
    traveledCount,
    bucketCount,
    traveledIsoCodes,
    bucketIsoCodes,
    loading,
    refresh,
  };
}
