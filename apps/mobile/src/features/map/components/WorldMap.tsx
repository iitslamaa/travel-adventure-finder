import React, { useEffect, useMemo, useRef, useState } from 'react';
import { View } from 'react-native';
import MapView, { LatLng } from 'react-native-maps';

import { useGeoJson } from '../hooks/useGeoJson';
import { CountryPolygon } from './CountryPolygon';
import { buildCountryOverlay } from '../utils/buildCountryOverlay';

import countrySeeds from '../../../../../../apps/web/data/seeds/countries.json';

function convertPolygon(coords: number[][]): LatLng[] {
  return coords.map(([lng, lat]) => ({
    latitude: lat,
    longitude: lng,
  }));
}

function extractPolygons(feature: any): LatLng[][] {
  const { geometry } = feature;
  if (!geometry) return [];

  const results: LatLng[][] = [];

  if (geometry.type === 'Polygon') {
    for (const ring of geometry.coordinates ?? []) {
      results.push(convertPolygon(ring));
    }
  }

  if (geometry.type === 'MultiPolygon') {
    for (const polygon of geometry.coordinates ?? []) {
      for (const ring of polygon ?? []) {
        results.push(convertPolygon(ring));
      }
    }
  }

  return results;
}

type WorldMapProps = {
  countries?: string[];
  selectedIso?: string | null;
  onSelect?: (iso: string) => void;
};

export function WorldMap({
  countries = [],
  selectedIso,
  onSelect,
}: WorldMapProps) {
  const { fullFeatures, simplifiedFeatures } = useGeoJson();

  const ISO2_RE = /^[A-Z]{2}$/;

  const ISO3_TO_ISO2: Record<string, string> = useMemo(() => {
    const map: Record<string, string> = {};
    for (const c of countrySeeds as any[]) {
      if (c.iso3 && c.iso2) {
        map[String(c.iso3).toUpperCase()] = String(c.iso2).toUpperCase();
      }
    }
    return map;
  }, []);

  function normalizeIso(value?: string | null): string | undefined {
    if (!value) return undefined;

    const upper = value.trim().toUpperCase();
    if (upper === 'UK') return 'GB';
    if (ISO2_RE.test(upper)) return upper;

    return undefined;
  }

  const mapRef = useRef<MapView | null>(null);
  const [isMapReady, setIsMapReady] = useState(false);

  // Use simplified features for world view; full features only for selected
  const sourceFeatures = selectedIso ? fullFeatures : simplifiedFeatures;

  const polygons = useMemo(() => {
    return (sourceFeatures ?? []).flatMap((feature: any, featureIndex: number) => {
      const NAME_OVERRIDES: Record<string, string> = {
        'Taiwan': 'TW',
        'French Guiana': 'GF',
        'Martinique': 'MQ',
        'Guadeloupe': 'GP',
        'Réunion': 'RE',
        'Mayotte': 'YT',
      };

      const featureName = feature?.properties?.NAME;

      const rawIso =
        // Hard override by NAME first
        NAME_OVERRIDES[featureName] ??
        // Natural Earth ISO_A2
        (feature?.properties?.ISO_A2 && feature?.properties?.ISO_A2 !== '-99'
          ? feature.properties.ISO_A2
          : feature?.properties?.ISO_A2_EH && feature?.properties?.ISO_A2_EH !== '-99'
          ? feature.properties.ISO_A2_EH
          : feature?.properties?.POSTAL && feature?.properties?.POSTAL.length === 2
          ? feature.properties.POSTAL
          : feature?.properties?.ISO_A3_EH && feature?.properties?.ISO_A3_EH.length === 3
          ? feature.properties.ISO_A3_EH.slice(0, 2)
          : feature?.properties?.ISO_A3 && feature?.properties?.ISO_A3.length === 3
          ? feature.properties.ISO_A3.slice(0, 2)
          : undefined)
        // geoBoundaries fallback using shapeGroup (ISO3)
        ?? (feature?.properties?.shapeGroup
          ? ISO3_TO_ISO2[String(feature.properties.shapeGroup).toUpperCase()]
          : undefined);

      const datasetIso = normalizeIso(rawIso);

      if (!datasetIso) {
        if (__DEV__) {
          console.warn(
            'Missing ISO_A2 on feature:',
            feature?.properties?.NAME
          );
        }
        return [];
      }

      // Skip Antarctica only
      if (datasetIso === 'AQ') return [];

      const rings = extractPolygons(feature);

      return rings.map((coords, ringIndex) => ({
        key: `${featureIndex}-${ringIndex}`,
        datasetIso,
        coords,
      }));
    });
  }, [sourceFeatures, ISO3_TO_ISO2]);

  const polygonsByIso = useMemo(() => {
    const map = new Map<string, typeof polygons>();
    for (const p of polygons) {
      if (!map.has(p.datasetIso)) {
        map.set(p.datasetIso, []);
      }
      map.get(p.datasetIso)!.push(p);
    }
    return map;
  }, [polygons]);

  // Zoom when a country is selected
  useEffect(() => {
    if (!isMapReady) return;
    if (!selectedIso) return;

    const normalized = normalizeIso(selectedIso);
    if (!normalized) return;

    const isoPolys = polygonsByIso.get(normalized) ?? [];

    // Keep ALL rings for rendering
    const selected = isoPolys;

    // Compute area for each ring
    const computeArea = (coords: typeof isoPolys[number]['coords']) => {
      let total = 0;
      for (let i = 0; i < coords.length; i++) {
        const p1 = coords[i];
        const p2 = coords[(i + 1) % coords.length];
        total += p1.longitude * p2.latitude - p2.longitude * p1.latitude;
      }
      return Math.abs(total);
    };

    const ringAreas = isoPolys.map(p => ({
      poly: p,
      area: computeArea(p.coords),
    }));

    const maxArea = ringAreas.length
      ? Math.max(...ringAreas.map(r => r.area))
      : 0;

    let zoomRings;

    if (normalized === 'BQ') {
      // Bonaire: largest ring only
      const largest = ringAreas.reduce((a, b) => (b.area > a.area ? b : a), ringAreas[0]);
      zoomRings = largest ? [largest.poly] : [];
    } else if (normalized === 'AG') {
      // Antigua & Barbuda: include both islands
      zoomRings = isoPolys;
    } else {
      // Default: include rings >= 5% of largest
      zoomRings = ringAreas
        .filter(r => r.area >= maxArea * 0.05)
        .map(r => r.poly);
    }

    // Hardcoded mainland zoom overrides (ignore overseas territories)
    const ZOOM_OVERRIDES: Record<string, { latitude: number; longitude: number; latitudeDelta: number; longitudeDelta: number }> = {
      // Antarctica
      'AQ': { latitude: -82, longitude: 0, latitudeDelta: 35, longitudeDelta: 35 },

      // Antigua & Barbuda
      'AG': { latitude: 17.18, longitude: -61.79, latitudeDelta: 1.2, longitudeDelta: 1.2 },

      // Bouvet Island (more zoomed-out framing)
      'BV': { latitude: -54.43, longitude: 3.36, latitudeDelta: 2.5, longitudeDelta: 2.5 },

      // China (zoom out more)
      'CN': { latitude: 35, longitude: 103, latitudeDelta: 34, longitudeDelta: 34 },

      // Christmas Island (slightly tighter)
      'CX': { latitude: -10.45, longitude: 105.65, latitudeDelta: 2.0, longitudeDelta: 2.0 },

      // United Kingdom
      'GB': { latitude: 54.5, longitude: -3, latitudeDelta: 10, longitudeDelta: 10 },

      // Greenland (zoomed out and moved much lower)
      'GL': { latitude: 52, longitude: -42, latitudeDelta: 70, longitudeDelta: 70 },

      // Russia (zoom out more)
      'RU': { latitude: 61, longitude: 105, latitudeDelta: 60, longitudeDelta: 120 },

      // United States (zoom out more incl. Alaska)
      'US': { latitude: 39, longitude: -98, latitudeDelta: 55, longitudeDelta: 90 },

      // Canada (shift down slightly)
      'CA': { latitude: 56, longitude: -96, latitudeDelta: 50, longitudeDelta: 80 },

      // Singapore (tight zoom)
      'SG': { latitude: 1.35, longitude: 103.82, latitudeDelta: 0.4, longitudeDelta: 0.4 },

      // Vatican City (very tight zoom)
      'VA': { latitude: 41.9029, longitude: 12.4534, latitudeDelta: 0.08, longitudeDelta: 0.08 },

      // Sierra Leone (force mainland framing)
      'SL': { latitude: 8.6, longitude: -11.8, latitudeDelta: 4.5, longitudeDelta: 4.5 },

      // France (mainland only feel)
      'FR': { latitude: 46.5, longitude: 2.5, latitudeDelta: 10, longitudeDelta: 10 },

      // Netherlands (mainland only feel)
      'NL': { latitude: 52.2, longitude: 5.3, latitudeDelta: 5, longitudeDelta: 5 },

      // Libya
      'LY': { latitude: 27, longitude: 17, latitudeDelta: 20, longitudeDelta: 20 },
    };

    if (ZOOM_OVERRIDES[normalized]) {
      const override = ZOOM_OVERRIDES[normalized];
      mapRef.current?.animateToRegion(
        {
          latitude: override.latitude,
          longitude: override.longitude,
          latitudeDelta: override.latitudeDelta,
          longitudeDelta: override.longitudeDelta,
        },
        500
      );
      return;
    }

    if (selected.length === 0) {
      console.log('❌ ZOOM FAILED');
      console.log('Selected ISO:', selectedIso);
      console.log('Normalized ISO:', normalized);
      console.log(
        'Available ISO sample:',
        polygons.slice(0, 20).map((p) => p.datasetIso)
      );
      return;
    }

    let minLat = Infinity;
    let maxLat = -Infinity;
    let minLng = Infinity;
    let maxLng = -Infinity;

    for (const ring of (zoomRings.length ? zoomRings : selected)) {
      for (const point of ring.coords) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    const centerLat = (minLat + maxLat) / 2;
    const centerLng = (minLng + maxLng) / 2;

    const rawLatDelta = (maxLat - minLat) * 1.3;
    const rawLngDelta = (maxLng - minLng) * 1.3;

    // Only enforce minimum zoom for small countries
    const MIN_DELTA =
      rawLatDelta < 0.3 ? 0.3 :      // tiny islands
      rawLatDelta < 1 ? 1 :          // small countries
      0;                             // no artificial floor for large countries

    const latitudeDelta = MIN_DELTA > 0
      ? Math.max(rawLatDelta, MIN_DELTA)
      : rawLatDelta;

    const longitudeDelta = MIN_DELTA > 0
      ? Math.max(rawLngDelta, MIN_DELTA)
      : rawLngDelta;

    mapRef.current?.animateToRegion(
      {
        latitude: centerLat,
        longitude: centerLng,
        latitudeDelta,
        longitudeDelta,
      },
      500
    );
  }, [selectedIso, isMapReady, polygons]);

  const normalizedSelected = normalizeIso(selectedIso ?? null);

  if (__DEV__) {
    console.log('===== WORLD MAP DEBUG =====');
    console.log('selectedIso prop:', selectedIso);
    console.log('normalizedSelected:', normalizedSelected);
    console.log('total polygons:', polygons.length);
    const isoCounts: Record<string, number> = {};
    for (const p of polygons) {
      if (!p.datasetIso) continue;
      isoCounts[p.datasetIso] = (isoCounts[p.datasetIso] || 0) + 1;
    }
    console.log('ISO counts sample:', Object.entries(isoCounts).slice(0, 20));
  }

  const worldPolygons = useMemo(() => {
    if (normalizedSelected) return [];

    // Render ALL rings for all countries in world view
    const all: typeof polygons = [];

    for (const [, isoPolygons] of polygonsByIso) {
      for (const poly of isoPolygons) {
        all.push(poly);
      }
    }

    return all;
  }, [normalizedSelected, polygonsByIso]);

  const selectedPolygons = normalizedSelected
    ? polygonsByIso.get(normalizedSelected) ?? []
    : [];

  return (
    <View style={{ flex: 1 }}>
      <MapView
        style={{ flex: 1 }}
        ref={(ref) => {
          mapRef.current = ref;
        }}
        onMapReady={() => setIsMapReady(true)}
        initialRegion={{
          latitude: 20,
          longitude: 0,
          latitudeDelta: 60,
          longitudeDelta: 60,
        }}
      >
        {(normalizedSelected ? selectedPolygons : worldPolygons).map((item) => {
          const iso = item.datasetIso;
          if (!iso) return null;

          return (
            <CountryPolygon
              key={item.key}
              iso={iso}
              coordinates={item.coords}
              overlay={buildCountryOverlay({
                iso,
                selectedIso: normalizedSelected ?? undefined,
                highlightedIsos: countries.map((c) => normalizeIso(c)).filter((c): c is string => !!c),
              })}
              onPress={(pressedIso) => {
                console.log('🟡 POLYGON PRESSED');
                console.log('Pressed ISO:', pressedIso);
                console.log('Current selectedIso prop:', selectedIso);
                console.log('Normalized selectedIso:', normalizedSelected);
                onSelect?.(pressedIso);
              }}
            />
          );
        })}
      </MapView>
    </View>
  );
}
