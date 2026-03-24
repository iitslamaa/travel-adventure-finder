import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const args = parseArgs(process.argv.slice(2));
const researchDir = path.resolve(
  args["input-dir"] ?? path.join(ROOT, "packages/data/research")
);
const migrationName = args.name ?? "place_language_override_batches";
const timestamp = args.timestamp ?? formatTimestamp(new Date());

const inputFiles = fs.readdirSync(researchDir)
  .filter((name) => /^place_language_overrides\.researched\.batch\d+\.json$/i.test(name))
  .sort((lhs, rhs) => lhs.localeCompare(rhs, undefined, { numeric: true }))
  .map((name) => path.join(researchDir, name));

if (inputFiles.length === 0) {
  throw new Error(`No researched override batches found in ${researchDir}`);
}

const rows = inputFiles.flatMap((filePath) => JSON.parse(fs.readFileSync(filePath, "utf8")));
const outputPath = path.join(ROOT, "supabase/migrations", `${timestamp}_${migrationName}.sql`);

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, buildMigration(rows, inputFiles.map((filePath) => path.basename(filePath))));

console.log(`Wrote ${rows.length} researched override rows to ${outputPath}`);

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

function formatTimestamp(date) {
  const parts = [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, "0"),
    String(date.getUTCDate()).padStart(2, "0"),
    String(date.getUTCHours()).padStart(2, "0"),
    String(date.getUTCMinutes()).padStart(2, "0"),
    String(date.getUTCSeconds()).padStart(2, "0")
  ];

  return parts.join("");
}

function buildMigration(rows, sourceFiles) {
  const values = rows.map((row) => {
    const placeType = String(row.place_type);
    const placeCode = String(row.place_code);
    const languages = JSON.stringify(row.languages ?? []).replaceAll("'", "''");
    const notes = String(row.notes ?? "");
    const reason = String(row.override_reason ?? "manual_override");
    const evidence = JSON.stringify(row.evidence ?? []).replaceAll("'", "''");

    return `  (${sqlString(placeType)}, ${sqlString(placeCode)}, '${languages}'::jsonb, ${sqlString(notes)}, ${sqlString(reason)}, '${evidence}'::jsonb)`;
  }).join(",\n");

  const sourcesComment = sourceFiles.map((file) => `--   ${file}`).join("\n");

  return `-- Generated from researched place-language override batches:
${sourcesComment}

insert into place_language_profile_overrides (
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
