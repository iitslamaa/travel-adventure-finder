import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const INPUT_PATH = path.join(
  ROOT,
  "apps/ios/TravelScoreriOS/App/Resources/global_languages.json"
);
const OUTPUT_PATH = path.join(ROOT, "supabase/seeds/app_languages.sql");

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

const raw = fs.readFileSync(INPUT_PATH, "utf8");
const languages = JSON.parse(raw);

const deduped = Array.from(
  new Map(
    languages.map((language) => [
      language.base.toLowerCase(),
      {
        code: language.base.toLowerCase(),
        base_code: language.base.toLowerCase(),
        display_name: language.displayName,
      },
    ])
  ).values()
).sort((a, b) => a.display_name.localeCompare(b.display_name));

const values = deduped
  .map(
    (language) =>
      `  (${sqlString(language.code)}, ${sqlString(language.base_code)}, ${sqlString(language.display_name)})`
  )
  .join(",\n");

const sql = `insert into app_languages (code, base_code, display_name)
values
${values}
on conflict (code) do update
set
  base_code = excluded.base_code,
  display_name = excluded.display_name,
  updated_at = now();
`;

fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
fs.writeFileSync(OUTPUT_PATH, sql);

console.log(`Wrote ${deduped.length} language rows to ${OUTPUT_PATH}`);
