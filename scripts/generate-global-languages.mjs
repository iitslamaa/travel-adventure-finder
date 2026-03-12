import fs from "fs";
import path from "path";

const ROOT = process.cwd();
const REG_PATH = path.join(ROOT, "scripts/data/language-subtag-registry.txt");
const OUT_PATH = path.join(
  ROOT,
  "apps/ios/TravelScoreriOS/App/Resources/global_languages.json"
);

function parseRegistry(text) {
  const chunks = text.split("\n%%\n");
  const records = [];

  for (const chunk of chunks) {
    const lines = chunk.split("\n").filter(Boolean);
    const rec = {};
    let currentKey = null;

    for (const line of lines) {
      if (/^\s/.test(line) && currentKey) {
        rec[currentKey] = (rec[currentKey] ?? "") + " " + line.trim();
        continue;
      }

      const idx = line.indexOf(":");
      if (idx === -1) continue;

      const key = line.slice(0, idx).trim();
      const value = line.slice(idx + 1).trim();

      currentKey = key;

      if (key === "Description") {
        if (!rec.Description) {
          rec.Description = [value];
        } else if (Array.isArray(rec.Description)) {
          rec.Description.push(value);
        } else {
          rec.Description = [rec.Description, value];
        }
      } else {
        rec[key] = value;
      }
    }

    if (Object.keys(rec).length) records.push(rec);
  }

  return records;
}

function isDeprecated(rec) {
  return Boolean(rec.Deprecated);
}

function safeDisplayName(rec) {
  if (Array.isArray(rec.Description)) {
    return rec.Description[0];
  }
  return rec.Description ?? rec.Subtag ?? rec.Tag ?? "Unknown";
}

if (!fs.existsSync(REG_PATH)) {
  console.error("Registry file not found:", REG_PATH);
  process.exit(1);
}

const raw = fs.readFileSync(REG_PATH, "utf8");
const records = parseRegistry(raw);

const languages = [];

for (const rec of records) {
  if (rec.Type === "language") {
    if (isDeprecated(rec)) continue;
    if (!rec.Subtag) continue;

    languages.push({
      code: rec.Subtag,
      base: rec.Subtag,
      displayName: safeDisplayName(rec),
    });
  }

  if (rec.Type === "grandfathered" || rec.Type === "redundant") {
    if (isDeprecated(rec)) continue;
    if (!rec.Tag) continue;

    const base = rec.Tag.split("-")[0];

    languages.push({
      code: rec.Tag,
      base,
      displayName: safeDisplayName(rec),
    });
  }
}

const deduped = Array.from(
  new Map(languages.map((l) => [l.code, l])).values()
).sort((a, b) => a.displayName.localeCompare(b.displayName));

fs.mkdirSync(path.dirname(OUT_PATH), { recursive: true });
fs.writeFileSync(OUT_PATH, JSON.stringify(deduped, null, 2) + "\n");

console.log(`✅ Generated ${deduped.length} languages.`);
console.log(`📁 Output: ${OUT_PATH}`);