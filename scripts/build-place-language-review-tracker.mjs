import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const geoJSONPath = path.join(ROOT, "apps/ios/TravelScoreriOS/countries.geojson");
const researchDir = path.join(ROOT, "packages/data/research");
const outputPath = path.join(ROOT, "packages/data/research/place_language_review_tracker.csv");

const geoJSON = JSON.parse(fs.readFileSync(geoJSONPath, "utf8"));
const appPlaceCodes = [...new Set(
  geoJSON.features
    .map((feature) => String(feature.properties?.ISO_A2 ?? "").trim())
    .filter(Boolean)
)].sort();

const batchFiles = fs.readdirSync(researchDir)
  .filter((name) => /^place_language_overrides\.researched\.batch\d+\.json$/i.test(name))
  .sort((lhs, rhs) => lhs.localeCompare(rhs, undefined, { numeric: true }));

const reviewedByCode = new Map();

for (const batchFile of batchFiles) {
  const rows = JSON.parse(fs.readFileSync(path.join(researchDir, batchFile), "utf8"));

  for (const row of rows) {
    const placeCode = String(row.place_code ?? "").trim().toUpperCase();
    if (!placeCode) continue;

    reviewedByCode.set(placeCode, {
      batch: batchFile,
      overrideReason: row.override_reason ?? "",
      evidenceCount: Array.isArray(row.evidence) ? row.evidence.length : 0
    });
  }
}

const csvRows = [
  ["place_type", "place_code", "review_status", "batch_file", "override_reason", "evidence_count"].join(",")
];

for (const placeCode of appPlaceCodes) {
  const reviewed = reviewedByCode.get(placeCode);
  csvRows.push([
    "country",
    placeCode,
    reviewed ? "reviewed_override" : "pending_review",
    reviewed?.batch ?? "",
    reviewed?.overrideReason ?? "",
    reviewed?.evidenceCount ?? 0
  ].join(","));
}

fs.writeFileSync(outputPath, `${csvRows.join("\n")}\n`);

const reviewedCount = appPlaceCodes.filter((placeCode) => reviewedByCode.has(placeCode)).length;
console.log(`Wrote tracker for ${appPlaceCodes.length} app places to ${outputPath}`);
console.log(`Reviewed: ${reviewedCount}`);
console.log(`Pending: ${appPlaceCodes.length - reviewedCount}`);
