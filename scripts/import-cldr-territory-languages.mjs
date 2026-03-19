import fs from "fs";
import os from "os";
import path from "path";
import { execFileSync } from "child_process";

const ROOT = process.cwd();
const LANGUAGE_CATALOG_PATH = path.join(
  ROOT,
  "apps/ios/TravelScoreriOS/App/Resources/global_languages.json"
);
const DEFAULT_OUTPUT_PATH = path.join(
  ROOT,
  "packages/data/seed/place_language_profiles.raw.cldr.json"
);

const args = parseArgs(process.argv.slice(2));
const version = args.version ?? "48.1";
const outputPath = path.resolve(args.out ?? DEFAULT_OUTPUT_PATH);
const includeRecognized = args.includeRecognized === "true";
const keepRegional = args.keepRegional !== "false";

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

async function main() {
  const languages = JSON.parse(fs.readFileSync(LANGUAGE_CATALOG_PATH, "utf8"));
  const supportedCodes = new Set(languages.map((entry) => entry.base.toLowerCase()));

  const xml = await loadSupplementalDataXML(version);
  const profiles = parseTerritoryProfiles(xml, {
    supportedCodes,
    includeRecognized,
    keepRegional,
    version,
  });

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(profiles, null, 2) + "\n");

  console.log(`Wrote ${profiles.length} CLDR country profiles to ${outputPath}`);
  console.log(`CLDR version: ${version}`);
}

function parseArgs(argv) {
  const parsed = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];

    if (!token.startsWith("--")) continue;

    const key = token.slice(2);
    const next = argv[index + 1];

    if (!next || next.startsWith("--")) {
      parsed[key] = "true";
      continue;
    }

    parsed[key] = next;
    index += 1;
  }

  return parsed;
}

async function loadSupplementalDataXML(version) {
  const url = `https://www.unicode.org/Public/cldr/${version}/core.zip`;
  const tempZipPath = path.join(os.tmpdir(), `cldr-core-${version}.zip`);

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download CLDR core.zip for ${version}: ${response.status} ${response.statusText}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  fs.writeFileSync(tempZipPath, Buffer.from(arrayBuffer));

  try {
    return execFileSync(
      "unzip",
      ["-p", tempZipPath, "common/supplemental/supplementalData.xml"],
      { encoding: "utf8" }
    );
  } finally {
    try {
      fs.unlinkSync(tempZipPath);
    } catch {
      // ignore cleanup failure
    }
  }
}

function parseTerritoryProfiles(
  xml,
  { supportedCodes, includeRecognized, keepRegional, version }
) {
  const territoryInfoMatch = xml.match(/<territoryInfo>([\s\S]*?)<\/territoryInfo>/);
  if (!territoryInfoMatch) {
    throw new Error("Could not find <territoryInfo> in CLDR supplementalData.xml");
  }

  const territorySection = territoryInfoMatch[1];
  const territoryMatches = territorySection.matchAll(
    /<territory\b([^>]*)>([\s\S]*?)<\/territory>/g
  );

  const profiles = [];

  for (const match of territoryMatches) {
    const territoryAttrs = parseAttributes(match[1]);
    const countryISO2 = territoryAttrs.type;
    const territoryBody = match[2];

    if (!countryISO2 || !/^[A-Z]{2}$/.test(countryISO2)) {
      continue;
    }

    const languageEntries = [];
    const languageMatches = territoryBody.matchAll(/<languagePopulation\b([^/>]*)\/>/g);

    for (const languageMatch of languageMatches) {
      const attrs = parseAttributes(languageMatch[1]);
      const rawCode = attrs.type?.toLowerCase();
      const status = attrs.officialStatus;
      const populationPercent = Number(attrs.populationPercent ?? "0");

      if (!rawCode || !supportedCodes.has(rawCode)) {
        continue;
      }

      const mappedType = mapOfficialStatus(status, { includeRecognized, keepRegional });
      if (!mappedType) {
        continue;
      }

      languageEntries.push({
        code: rawCode,
        type: mappedType,
        coverage: normalizeCoverage(populationPercent),
      });
    }

    const deduped = Array.from(
      new Map(
        languageEntries.map((entry) => [
          `${entry.code}:${entry.type}`,
          entry,
        ])
      ).values()
    ).sort((left, right) => right.coverage - left.coverage || left.code.localeCompare(right.code));

    if (!deduped.length) {
      continue;
    }

    profiles.push({
      place_type: "country",
      place_code: countryISO2,
      source: "cldr_territory_language_info",
      source_version: version,
      notes: "Imported from CLDR territoryInfo. This is official-language baseline data only, not traveler usability.",
      languages: deduped,
    });
  }

  return profiles.sort((left, right) => left.place_code.localeCompare(right.place_code));
}

function parseAttributes(rawAttrs) {
  const attrs = {};
  const attrMatches = rawAttrs.matchAll(/([A-Za-z_]+)="([^"]*)"/g);

  for (const [, key, value] of attrMatches) {
    attrs[key] = value;
  }

  return attrs;
}

function mapOfficialStatus(status, { includeRecognized, keepRegional }) {
  switch (status) {
    case "official":
    case "de_facto_official":
      return "official";
    case "official_regional":
      return keepRegional ? "minor" : null;
    case "recognized":
      return includeRecognized ? "minor" : null;
    default:
      return null;
  }
}

function normalizeCoverage(populationPercent) {
  if (!Number.isFinite(populationPercent)) {
    return 0;
  }

  const value = Math.min(Math.max(populationPercent / 100, 0), 1);
  return Number(value.toFixed(3));
}
