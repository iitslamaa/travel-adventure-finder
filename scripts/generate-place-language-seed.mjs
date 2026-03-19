import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const args = parseArgs(process.argv.slice(2));
const inputPath = path.resolve(
  args.input ?? path.join(ROOT, "packages/data/seed/place_language_profiles.raw.json")
);
const target = args.target ?? "raw";

const outputPath = path.join(
  ROOT,
  "supabase/seeds",
  target === "overrides"
    ? "place_language_profile_overrides.sql"
    : "place_language_profiles_raw.sql"
);

const rows = JSON.parse(fs.readFileSync(inputPath, "utf8"));
const sql = target === "overrides"
  ? buildOverrideSeed(rows)
  : buildRawSeed(rows);

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, sql);

console.log(`Wrote ${rows.length} ${target} place language rows to ${outputPath}`);

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

function buildRawSeed(rows) {
  const values = rows.map((row) => {
    const placeType = String(row.place_type);
    const placeCode = String(row.place_code);
    const source = String(row.source ?? "manual");
    const sourceVersion = String(row.source_version ?? "v1");
    const languages = JSON.stringify(row.languages ?? []).replaceAll("'", "''");
    const notes = String(row.notes ?? "");

    return `  (${sqlString(placeType)}, ${sqlString(placeCode)}, ${sqlString(source)}, ${sqlString(sourceVersion)}, '${languages}'::jsonb, ${sqlString(notes)})`;
  }).join(",\n");

  return `insert into place_language_profiles_raw (
  place_type,
  place_code,
  source,
  source_version,
  languages,
  notes
)
values
${values}
on conflict (place_type, place_code, source) do update
set
  source_version = excluded.source_version,
  languages = excluded.languages,
  notes = excluded.notes,
  updated_at = now();
`;
}

function buildOverrideSeed(rows) {
  const values = rows.map((row) => {
    const placeType = String(row.place_type);
    const placeCode = String(row.place_code);
    const languages = JSON.stringify(row.languages ?? []).replaceAll("'", "''");
    const notes = String(row.notes ?? "");
    const reason = String(row.override_reason ?? "manual_override");
    const evidence = JSON.stringify(row.evidence ?? []).replaceAll("'", "''");

    return `  (${sqlString(placeType)}, ${sqlString(placeCode)}, '${languages}'::jsonb, ${sqlString(notes)}, ${sqlString(reason)}, '${evidence}'::jsonb)`;
  }).join(",\n");

  return `insert into place_language_profile_overrides (
  place_type,
  place_code,
  languages,
  notes,
  override_reason,
  evidence
)
values
${values}
on conflict (place_type, place_code) do update
set
  languages = excluded.languages,
  notes = excluded.notes,
  override_reason = excluded.override_reason,
  evidence = excluded.evidence,
  updated_at = now();
`;
}

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}
