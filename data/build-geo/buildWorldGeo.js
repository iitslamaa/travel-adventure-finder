const fs = require("fs");
const path = require("path");

const seedsPath = path.resolve("apps/web/data/seeds/countries.json");
const adminCountryPath = path.resolve("data/build-geo/geoBoundaries.ADM0.full.geojson");
const mapUnitsPath = path.resolve("apps/mobile/assets/geo/countries.geo.json");
const outputPath = path.resolve("data/build-geo/travelaf.world.final.geo.json");

const seeds = JSON.parse(fs.readFileSync(seedsPath, "utf-8"));
const adminCountry = JSON.parse(fs.readFileSync(adminCountryPath, "utf-8"));
const mapUnits = JSON.parse(fs.readFileSync(mapUnitsPath, "utf-8"));

const seedIsoSet = new Set(seeds.map(s => s.iso2.toUpperCase()));

const countryFeatures = adminCountry.features || [];
const mapUnitFeatures = mapUnits.features || [];

const featureByIso = {};

// 1️⃣ Load sovereign features from geoBoundaries (ISO3 via shapeGroup)
for (const f of countryFeatures) {
  const iso3 = (f?.properties?.shapeGroup || "").toUpperCase();
  if (!iso3) continue;

  const seedMatch = seeds.find(s => s.iso3.toUpperCase() === iso3);
  if (!seedMatch) continue;

  const iso2 = seedMatch.iso2.toUpperCase();

  if (seedIsoSet.has(iso2)) {
    featureByIso[iso2] = f;
  }
}

// 2️⃣ Fill missing ISO2 from Natural Earth map_units (territories)
for (const f of mapUnitFeatures) {
  const iso2 = (
    f?.properties?.ISO_A2 ||
    f?.properties?.iso_a2 ||
    ""
  ).toUpperCase();

  if (!iso2) continue;
  if (!seedIsoSet.has(iso2)) continue;

  // Only fill if sovereign layer did not already set it
  if (!featureByIso[iso2]) {
    featureByIso[iso2] = f;
  }
}

// 2️⃣b Fill remaining using ISO3 from map_units (for territories like GF, GP, MQ, RE, etc.)
for (const f of mapUnitFeatures) {
  const iso3 = (
    f?.properties?.ISO_A3 ||
    f?.properties?.iso_a3 ||
    ""
  ).toUpperCase();

  if (!iso3) continue;

  const seedMatch = seeds.find(s => s.iso3.toUpperCase() === iso3);
  if (!seedMatch) continue;

  const iso2 = seedMatch.iso2.toUpperCase();

  if (!seedIsoSet.has(iso2)) continue;

  if (!featureByIso[iso2]) {
    featureByIso[iso2] = f;
  }
}

// 3️⃣ Final fallback: try ISO3 + name match across BOTH datasets
for (const iso of seedIsoSet) {
  if (featureByIso[iso]) continue;

  const seed = seeds.find(s => s.iso2.toUpperCase() === iso);
  if (!seed) continue;

  const iso3 = (seed.iso3 || "").toUpperCase();
  const nameLower = (seed.name || "").toLowerCase();

  // Try ISO3 in geoBoundaries (shapeGroup)
  let match = countryFeatures.find(f =>
    (f?.properties?.shapeGroup || "").toUpperCase() === iso3
  );

  // Try ISO3 in map_units
  if (!match) {
    match = mapUnitFeatures.find(f =>
      (
        f?.properties?.ISO_A3 ||
        f?.properties?.iso_a3 ||
        ""
      ).toUpperCase() === iso3
    );
  }

  // Try ISO2 in map_units
  if (!match) {
    match = mapUnitFeatures.find(f =>
      (
        f?.properties?.ISO_A2 ||
        f?.properties?.iso_a2 ||
        ""
      ).toUpperCase() === iso
    );
  }

  // Try name match across both datasets (shapeName, ADMIN, NAME_LONG)
  if (!match) {
    const nameMatchInCountry = countryFeatures.find(f =>
      (f?.properties?.shapeName || "").toLowerCase().includes(nameLower)
    );

    const nameMatchInUnits = mapUnitFeatures.find(f =>
      (
        f?.properties?.NAME_LONG ||
        f?.properties?.name_long ||
        f?.properties?.ADMIN ||
        ""
      ).toLowerCase().includes(nameLower)
    );

    match = nameMatchInCountry || nameMatchInUnits;
  }

  if (match) {
    featureByIso[iso] = match;
  }
}

// 3️⃣b Explicit patch for PS and UM (geoBoundaries naming differences)
for (const iso of ['PS', 'UM']) {
  if (featureByIso[iso]) continue;

  const seed = seeds.find(s => s.iso2.toUpperCase() === iso);
  if (!seed) continue;

  const iso3 = (seed.iso3 || '').toUpperCase();
  const nameLower = (seed.name || '').toLowerCase();

  let match = null;

  // PS specific: geoBoundaries uses ISO3 = PSE and name "Palestine"
  if (iso === 'PS') {
    match = countryFeatures.find(f =>
      (f?.properties?.shapeGroup || '').toUpperCase() === 'PSE'
    ) || countryFeatures.find(f =>
      (f?.properties?.shapeName || '').toLowerCase().includes('palestine')
    );
  }

  // UM specific: try ISO3 UMI or name match
  if (!match && iso === 'UM') {
    match = mapUnitFeatures.find(f =>
      (f?.properties?.ISO_A3 || '').toUpperCase() === 'UMI'
    ) || countryFeatures.find(f =>
      (f?.properties?.shapeName || '').toLowerCase().includes('minor')
    );
  }

  if (match) {
    featureByIso[iso] = match;
  }
}

// 4️⃣ Verify coverage and auto-generate minimal geometry for any remaining ISO
const missing = [];

for (const iso of seedIsoSet) {
  if (!featureByIso[iso]) {
    const seed = seeds.find(s => s.iso2.toUpperCase() === iso);

    if (seed && typeof seed.lat === 'number' && typeof seed.lng === 'number') {
      // Create minimal Point geometry fallback
      featureByIso[iso] = {
        type: "Feature",
        properties: {
          generated: true,
          iso2: iso,
          name: seed.name,
        },
        geometry: {
          type: "Point",
          coordinates: [seed.lng, seed.lat],
        },
      };
    } else {
      missing.push(iso);
    }
  }
}

console.log("Total ISO in seeds:", seedIsoSet.size);
console.log("Total ISO matched:", Object.keys(featureByIso).length);
console.log("Missing ISO:", missing);

// 4️⃣ Build final feature list
const finalFeatures = Object.values(featureByIso);

const output = {
  type: "FeatureCollection",
  features: finalFeatures,
};

fs.writeFileSync(
  outputPath,
  JSON.stringify(output)
);

console.log("Built:", outputPath);