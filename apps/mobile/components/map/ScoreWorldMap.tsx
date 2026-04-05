import React, { useMemo, useRef, useState } from "react";
import { View, StyleSheet, Pressable, Text } from "react-native";
import MapView, { Polygon, PROVIDER_GOOGLE } from "react-native-maps";
import { useRouter } from "expo-router";
import { useCountries } from "../../hooks/useCountries";
import worldGeo from "../../src/assets/geo/world.geo.json";
import ScrapbookBackground from "../theme/ScrapbookBackground";
import ScrapbookCard from "../theme/ScrapbookCard";
import TitleBanner from "../theme/TitleBanner";
import { useTheme } from "../../hooks/useTheme";

type SelectedCountry = {
  name: string;
  iso2: string;
  score?: number;
};

type PrecomputedFeature = {
  iso3: string;
  feature: any;
  polygons: { latitude: number; longitude: number }[][];
};

const ISO3_RE = /^[A-Z]{3}$/;

const ISO3_NAME_OVERRIDES: Record<string, string> = {
  FRANCE: "FRA",
  NORWAY: "NOR",
};

const ZOOM_OVERRIDES: Record<
  string,
  { latitude: number; longitude: number; latitudeDelta: number; longitudeDelta: number }
> = {
  FR: { latitude: 46.5, longitude: 2.5, latitudeDelta: 10, longitudeDelta: 10 },
  NO: { latitude: 64.8, longitude: 12.6, latitudeDelta: 12, longitudeDelta: 10 },
};

const mutedMapStyle = [
  { elementType: "geometry", stylers: [{ color: "#efe2cf" }] },
  { elementType: "labels.text.fill", stylers: [{ color: "#5f4b36" }] },
  { elementType: "labels.text.stroke", stylers: [{ color: "#f8f1e7" }] },
  { featureType: "administrative", elementType: "geometry.stroke", stylers: [{ color: "#b99f84" }] },
  { featureType: "poi", stylers: [{ visibility: "off" }] },
  { featureType: "road", stylers: [{ visibility: "off" }] },
  { featureType: "transit", stylers: [{ visibility: "off" }] },
  { featureType: "landscape.natural", elementType: "geometry", stylers: [{ color: "#ead8bf" }] },
  { featureType: "water", elementType: "geometry", stylers: [{ color: "#c9d9d7" }] },
];

function getScoreColor(score?: number) {
  if (score == null) return "rgba(168,154,138,0.18)";
  if (score >= 80) return "rgba(78,133,92,0.5)";
  if (score >= 60) return "rgba(214,170,78,0.5)";
  if (score >= 40) return "rgba(201,131,74,0.5)";
  return "rgba(181,92,79,0.5)";
}

function toIso3(value: unknown) {
  const normalized = String(value ?? "").trim().toUpperCase();
  return ISO3_RE.test(normalized) ? normalized : undefined;
}

function isoToFlag(iso2: string) {
  return iso2
    .toUpperCase()
    .replace(/./g, char => String.fromCodePoint(127397 + char.charCodeAt(0)));
}

function resolveFeatureIso3(feature: any) {
  const properties = feature?.properties ?? {};
  const candidates = [
    properties.iso_a3,
    properties.adm0_a3,
    properties.brk_a3,
    properties.gu_a3,
    properties.sov_a3,
    properties.adm0_a3_us,
    properties.adm0_a3_fr,
  ];

  for (const candidate of candidates) {
    const iso3 = toIso3(candidate);
    if (iso3 && iso3 !== "ATA") return iso3;
  }

  const nameCandidates = [
    properties.admin,
    properties.name,
    properties.name_en,
    properties.geounit,
    properties.sovereignt,
  ];

  for (const candidate of nameCandidates) {
    const override = ISO3_NAME_OVERRIDES[String(candidate ?? "").trim().toUpperCase()];
    if (override) return override;
  }

  return undefined;
}

const precomputedFeatures: PrecomputedFeature[] = worldGeo.features.flatMap((feature: any) => {
  const iso3 = resolveFeatureIso3(feature);
  const geometry = feature?.geometry;

  if (!iso3 || !geometry) return [];

  const polygons =
    geometry.type === "Polygon"
      ? [geometry.coordinates]
      : geometry.type === "MultiPolygon"
      ? geometry.coordinates
      : [];

  const normalizedPolygons = polygons
    .map((poly: any) =>
      poly[0].map(([lng, lat]: number[]) => ({
        latitude: lat,
        longitude: lng,
      }))
    )
    .filter((coords: { latitude: number; longitude: number }[]) => coords.length > 0);

  if (!normalizedPolygons.length) return [];

  return [{ iso3, feature, polygons: normalizedPolygons }];
});

export default function ScoreWorldMap() {
  const router = useRouter();
  const mapRef = useRef<MapView>(null);
  const { countries } = useCountries();
  const colors = useTheme();

  const [selected, setSelected] = useState<SelectedCountry | null>(null);

  const scoreLookup = useMemo(() => {
    const map: Record<string, number> = {};
    countries.forEach((c) => {
      if (c.iso3) {
        map[String(c.iso3).toUpperCase()] = c.facts?.scoreTotal ?? 0;
      }
    });
    return map;
  }, [countries]);

  const countryByIso3 = useMemo(() => {
    const map: Record<string, typeof countries[number]> = {};
    countries.forEach((country) => {
      const iso3 = String(country.iso3 ?? "").toUpperCase();
      if (iso3) {
        map[iso3] = country;
      }
    });
    return map;
  }, [countries]);

  const handlePress = (feature: any) => {
    if (!feature) return;

    const iso3 = resolveFeatureIso3(feature);
    if (!iso3) return;

    const matchedCountry = countryByIso3[iso3];
    const iso2 = matchedCountry?.iso2 ?? iso3.slice(0, 2);
    const score = scoreLookup[iso3];

    setSelected({
      name:
        matchedCountry?.name ??
        feature.properties?.admin ??
        feature.properties?.name_en ??
        feature.properties?.name,
      iso2,
      score,
    });

    const zoomOverride = ZOOM_OVERRIDES[iso2];
    if (zoomOverride) {
      mapRef.current?.animateToRegion(zoomOverride);
      return;
    }

    const geometry = feature.geometry;
    if (!geometry) return;

    // Collect ALL outer-ring coordinates (Polygon + MultiPolygon safe)
    const rings =
      geometry.type === "Polygon"
        ? [geometry.coordinates[0]]
        : geometry.type === "MultiPolygon"
        ? geometry.coordinates.map((poly: any) => poly[0])
        : [];

    const allCoords = rings.flat().map(([lng, lat]: number[]) => ({
      latitude: lat,
      longitude: lng,
    }));

    if (!allCoords.length) return;

    // Compute bounding box
    let minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    allCoords.forEach(({ latitude, longitude }: { latitude: number; longitude: number }) => {
      minLat = Math.min(minLat, latitude);
      maxLat = Math.max(maxLat, latitude);
      minLng = Math.min(minLng, longitude);
      maxLng = Math.max(maxLng, longitude);
    });

    const centerLat = (minLat + maxLat) / 2;
    const centerLng = (minLng + maxLng) / 2;

    mapRef.current?.animateToRegion({
      latitude: centerLat,
      longitude: centerLng,
      latitudeDelta: Math.max(2, (maxLat - minLat) * 1.2),
      longitudeDelta: Math.max(2, (maxLng - minLng) * 1.2),
    });
  };

  const renderedPolygons = useMemo(
    () =>
      precomputedFeatures.flatMap(({ iso3, feature, polygons }) => {
        const fillColor = getScoreColor(scoreLookup[iso3]);

        return polygons.map((coordinates, polyIndex) => (
          <Polygon
            key={`${iso3}-${polyIndex}`}
            coordinates={coordinates}
            strokeColor="rgba(110,88,67,0.28)"
            strokeWidth={0.8}
            fillColor={fillColor}
            tappable
            onPress={() => handlePress(feature)}
          />
        ));
      }),
    [scoreLookup]
  );

  return (
    <ScrapbookBackground>
      <View style={styles.container}>
        <View style={styles.header}>
          <TitleBanner title="Score Map" />
        </View>

        <View style={styles.mapWrap}>
          <MapView
            ref={mapRef}
            style={styles.map}
            initialRegion={{
              latitude: 20,
              longitude: 0,
              latitudeDelta: 60,
              longitudeDelta: 60,
            }}
            mapType="standard"
            provider={PROVIDER_GOOGLE}
            customMapStyle={mutedMapStyle}
          >
            {renderedPolygons}
          </MapView>
        </View>

        {selected && (
          <ScrapbookCard
            style={[
              styles.card,
              {
                alignSelf: 'center',
                width: '100%',
                maxWidth: 520,
              },
            ]}
            innerStyle={styles.cardInner}
          >
            <View style={styles.cardHeader}>
              <Text style={styles.flag}>{isoToFlag(selected.iso2)}</Text>
              <View style={styles.cardCopy}>
                <Text style={[styles.title, { color: colors.textPrimary }]}>
                  {selected.name}
                </Text>
                <Text style={[styles.scoreLine, { color: colors.textSecondary }]}>
                  Overall score:{" "}
                  <Text style={[styles.scoreValue, { color: colors.textPrimary }]}>
                    {selected.score ?? "N/A"}
                  </Text>
                </Text>
              </View>
            </View>

            <Pressable
              style={[styles.button, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
              onPress={() => {
                router.push({
                  pathname: "/country/[iso2]",
                  params: {
                    iso2: selected.iso2,
                    name: selected.name,
                  },
                });
              }}
            >
              <Text style={[styles.buttonText, { color: colors.textPrimary }]}>
                View country details
              </Text>
            </Pressable>
          </ScrapbookCard>
        )}
      </View>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "transparent" },
  header: {
    paddingTop: 10,
    paddingHorizontal: 16,
    paddingBottom: 8,
  },
  mapWrap: {
    flex: 1,
    marginHorizontal: 16,
    marginBottom: 148,
    borderRadius: 32,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(124, 102, 78, 0.24)",
    shadowColor: "#8d7559",
    shadowOpacity: 0.16,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 12 },
    elevation: 8,
  },
  map: {
    flex: 1,
  },
  card: {
    position: "absolute",
    bottom: 28,
    paddingHorizontal: 16,
  },
  cardInner: {
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    marginBottom: 12,
  },
  flag: {
    fontSize: 28,
  },
  cardCopy: {
    flex: 1,
    gap: 3,
  },
  title: {
    fontSize: 22,
    fontWeight: "700",
  },
  scoreLine: {
    fontSize: 14,
    lineHeight: 18,
  },
  scoreValue: {
    fontSize: 15,
    fontWeight: "700",
  },
  button: {
    padding: 12,
    borderRadius: 14,
    alignItems: "center",
    borderWidth: 1,
  },
  buttonText: {
    fontWeight: "600",
  },
});
