import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const INPUT_PATH =
  process.argv[2]
  ?? path.join(ROOT, "packages/data/seed/country_language_profiles.template.json");
const OUTPUT_PATH = path.join(ROOT, "supabase/seeds/country_language_profiles.sql");

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

const raw = fs.readFileSync(INPUT_PATH, "utf8");
const profiles = JSON.parse(raw);

const values = profiles
  .map((profile) => {
    const countryISO2 = String(profile.country_iso2).toUpperCase();
    const source = profile.source ?? "manual_cldr_hybrid";
    const sourceVersion = profile.source_version ?? "v1";
    const notes = profile.notes ?? "";
    const languages = JSON.stringify(profile.languages ?? []).replaceAll("'", "''");

    return `  (${sqlString(countryISO2)}, ${sqlString(source)}, ${sqlString(sourceVersion)}, '${languages}'::jsonb, ${sqlString(notes)})`;
  })
  .join(",\n");

const sql = `insert into country_language_profiles (
  country_iso2,
  source,
  source_version,
  languages,
  notes
)
values
${values}
on conflict (country_iso2) do update
set
  source = excluded.source,
  source_version = excluded.source_version,
  languages = excluded.languages,
  notes = excluded.notes,
  updated_at = now();
`;

fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
fs.writeFileSync(OUTPUT_PATH, sql);

console.log(`Wrote ${profiles.length} country language profiles to ${OUTPUT_PATH}`);
