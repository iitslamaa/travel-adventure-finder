import { useMemo } from 'react';

import worldFull from '../../../../assets/geo/travelaf.world.full.geo.json';
import worldSimplified from '../../../../assets/geo/travelaf.world.simplified.geo.json';

export function useGeoJson() {
  const fullFeatures = useMemo(() => {
    return (worldFull as any)?.features ?? [];
  }, []);

  const simplifiedFeatures = useMemo(() => {
    return (worldSimplified as any)?.features ?? [];
  }, []);

  return {
    fullFeatures,
    simplifiedFeatures,
  };
}