import React, { memo } from 'react';
import { Polygon, LatLng } from 'react-native-maps';
import { CountryFeatureOverlay } from '../types/map.types';

type Props = {
  coordinates: LatLng[];
  iso: string;
  overlay?: CountryFeatureOverlay;
  onPress?: (iso: string) => void;
};

function CountryPolygonComponent({
  coordinates,
  iso,
  overlay,
  onPress,
}: Props) {
  return (
    <Polygon
      coordinates={coordinates}
      tappable
      onPress={() => onPress?.(iso)}
      strokeColor={overlay?.strokeColor ?? '#000000'}
      fillColor={overlay?.fillColor ?? 'rgba(0, 0, 255, 0.35)'}
      strokeWidth={2}
    />
  );
}

export const CountryPolygon = memo(CountryPolygonComponent);
CountryPolygon.displayName = 'CountryPolygon';