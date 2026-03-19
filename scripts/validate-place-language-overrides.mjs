import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const researchDir = path.join(ROOT, "packages/data/research");
const appLanguagesSeedPath = path.join(ROOT, "supabase/seeds/app_languages.sql");

const batchFiles = fs.readdirSync(researchDir)
  .filter((name) => /^place_language_overrides\.researched\.batch\d+\.json$/i.test(name))
  .sort((lhs, rhs) => lhs.localeCompare(rhs, undefined, { numeric: true }));

if (!fs.existsSync(appLanguagesSeedPath)) {
  throw new Error(`Missing app language seed at ${appLanguagesSeedPath}`);
}

const supportedCodes = loadSupportedCodes(appLanguagesSeedPath);
const failures = [];

for (const fileName of batchFiles) {
  const filePath = path.join(researchDir, fileName);
  const rows = JSON.parse(fs.readFileSync(filePath, "utf8"));

  for (const row of rows) {
    for (const language of row.languages ?? []) {
      const code = String(language.code ?? "").trim().toLowerCase();

      if (!supportedCodes.has(code)) {
        failures.push({
          fileName,
          placeType: row.place_type,
          placeCode: row.place_code,
          code
        });
      }
    }
  }
}

if (failures.length > 0) {
  console.error("Found override language codes that do not exist in app_languages:");

  for (const failure of failures) {
    console.error(
      `- ${failure.fileName}: ${failure.placeType}/${failure.placeCode} uses unsupported code '${failure.code}'`
    );
  }

  process.exit(1);
}

console.log(`Validated ${batchFiles.length} researched override files against ${supportedCodes.size} app language codes.`);

function loadSupportedCodes(seedPath) {
  const codes = new Set();
  const pattern = /\('([^']+)',\s*'([^']+)',\s*'([^']+)'\)/g;
  const seed = fs.readFileSync(seedPath, "utf8");

  for (const match of seed.matchAll(pattern)) {
    codes.add(match[1].trim().toLowerCase());
  }

  return codes;
}
