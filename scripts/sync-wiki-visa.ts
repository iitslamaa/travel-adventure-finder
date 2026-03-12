try {
  require("dotenv").config({ override: true });
} catch {
  // Fall back to loading .env manually when dotenv is not installed.
  loadEnvFile();
}

function loadEnvFile() {
  const fs = require("fs");
  const path = require("path");
  const envPath = path.join(__dirname, "..", ".env");

  if (!fs.existsSync(envPath)) {
    return;
  }

  const raw = fs.readFileSync(envPath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const eqIndex = trimmed.indexOf("=");
    if (eqIndex === -1) continue;

    const key = trimmed.slice(0, eqIndex).trim();
    let value = trimmed.slice(eqIndex + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    process.env[key] = value;
  }
}

const COUNTRY_SEEDS = require("../apps/web/data/seeds/countries.json");

console.log("Starting visa sync script...");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const WIKI_URL =
  "https://en.wikipedia.org/wiki/Visa_requirements_for_United_States_citizens";

function normalize(text) {
  const normalized = String(text || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\[[^\]]+\]/g, " ")
    .replace(/&/g, "and")
    .replace(/['’]/g, "")
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  const tokens = normalized.split(" ").filter(Boolean);
  const collapsed = [];
  for (const token of tokens) {
    if (
      token.length === 1 &&
      /^[a-z0-9]$/.test(token) &&
      collapsed.length > 0 &&
      collapsed[collapsed.length - 1].length === 1 &&
      /^[a-z0-9]$/.test(collapsed[collapsed.length - 1])
    ) {
      collapsed[collapsed.length - 1] += token;
    } else {
      collapsed.push(token);
    }
  }

  return collapsed.join(" ");
}

function cleanDisplayName(text) {
  return String(text || "")
    .replace(/\[[^\]]+\]/g, " ")
    .replace(/\u00a0/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function splitAliasTokens(text) {
  return String(text || "")
    .split(/,| and |\/|;/i)
    .map((s) => cleanDisplayName(s))
    .filter(Boolean);
}

const MANUAL_ALIASES_BY_NORM = {
  bahamas: ["the bahamas", "commonwealth of the bahamas"],
  gambia: ["the gambia", "republic of the gambia"],
  taiwan: ["republic of china taiwan", "taiwan province of china"],
  curacao: ["curaçao"],
  "aland islands": ["aland", "aaland", "åland islands"],
  "saint martin": ["st martin", "saint martin french part"],
  "sint maarten": ["saint maarten", "sint maarten dutch part"],
  reunion: ["réunion"],
  "holy see": ["vatican", "vatican city", "holy see vatican city state"],
  "south korea": ["republic of korea", "korea south"],
  laos: ["lao", "lao peoples democratic republic"],
  palestine: ["palestinian territories", "palestinian territory"],
  "turks and caicos islands": ["turks and caicos"],
  "cote divoire": ["cote d ivoire", "ivory coast"],
  "united states virgin islands": [
    "u s virgin islands",
    "us virgin islands",
    "virgin islands u s",
    "virgin islands us",
    "u s virgin is",
  ],
};

const aliasToSeed = (() => {
  const map = new Map();

  for (const seed of COUNTRY_SEEDS) {
    const manualAliases = MANUAL_ALIASES_BY_NORM[normalize(seed.name)] || [];
    const labels = [
      seed.name,
      seed.officialName,
      ...(Array.isArray(seed.aliases) ? seed.aliases : []),
      ...manualAliases,
    ]
      .filter(Boolean)
      .filter((value) => value !== "undefined");

    for (const label of labels) {
      const key = normalize(label);
      if (key && !map.has(key)) {
        map.set(key, seed);
      }
    }
  }

  return map;
})();

function findSeedForVisitor(visitorToRaw) {
  const raw = cleanDisplayName(visitorToRaw);
  const candidates = new Set([
    raw,
    raw.replace(/\s*\([^)]*\)/g, " ").replace(/\s+/g, " ").trim(),
  ]);

  const parenMatch = raw.match(/\(([^)]+)\)/);
  if (parenMatch) {
    splitAliasTokens(parenMatch[1]).forEach((token) => candidates.add(token));
  }

  if (raw.includes(" - ")) {
    raw.split(" - ").forEach((part) => candidates.add(cleanDisplayName(part)));
  }

  if (raw.includes(",")) {
    raw.split(",").forEach((part) => candidates.add(cleanDisplayName(part)));
  }

  for (const candidate of candidates) {
    const key = normalize(candidate);
    if (aliasToSeed.has(key)) {
      return aliasToSeed.get(key);
    }
  }

  return null;
}

function findSeedsForGroupedVisitor(visitorToRaw) {
  const raw = cleanDisplayName(visitorToRaw);
  const results = [];
  const seen = new Set();

  const addCandidate = (candidate) => {
    const cleaned = cleanDisplayName(candidate);
    if (!cleaned) return;
    const key = normalize(cleaned);
    const seed = aliasToSeed.get(key);
    if (!seed || seen.has(seed.iso2)) return;
    seen.add(seed.iso2);
    results.push(seed);
  };

  const parenMatch = raw.match(/\(([^)]+)\)/);
  if (parenMatch) {
    splitAliasTokens(parenMatch[1]).forEach(addCandidate);
  }

  if (raw.includes(" - ")) {
    const rhs = raw.split(" - ").slice(1).join(" - ");
    splitAliasTokens(rhs.replace(/\(([^)]+)\)/g, " ")).forEach(addCandidate);
  }

  return results;
}

function extractAliases(visitorToRaw) {
  const aliases = new Set();
  let parentNorm = null;
  let isSpecialSubregion = false;

  const raw = cleanDisplayName(visitorToRaw);
  const seed = findSeedForVisitor(raw);

  // Detect "Parent - Subregion"
  if (raw.includes(" - ")) {
    const parts = raw.split(" - ");
    if (parts.length === 2) {
      parentNorm = normalize(parts[0]);
      isSpecialSubregion = true;
      splitAliasTokens(parts[1]).forEach((alias) => aliases.add(alias));
    }
  }

  // Extract names inside parentheses
  const parenMatch = raw.match(/\(([^)]+)\)/);
  if (parenMatch) {
    splitAliasTokens(parenMatch[1]).forEach((alias) => aliases.add(alias));
  }

  if (seed) {
    const seedLabels = [
      seed.name,
      seed.officialName,
      ...(Array.isArray(seed.aliases) ? seed.aliases : []),
      ...(MANUAL_ALIASES_BY_NORM[normalize(seed.name)] || []),
    ]
      .filter(Boolean)
      .filter((value) => value !== "undefined");

    seedLabels.forEach((label) => aliases.add(cleanDisplayName(label)));
  }

  const visitorNorm = normalize(raw);
  const aliasesNorm = [...aliases]
    .map(normalize)
    .filter(Boolean)
    .filter((alias) => alias !== visitorNorm)
    .filter((alias, index, array) => array.indexOf(alias) === index);

  return {
    aliasesNorm,
    parentNorm,
    isSpecialSubregion,
  };
}

function buildRowPayload({
  visitorToRaw,
  requirement,
  allowedStay,
  notes,
  aliasesNorm,
  parentNorm,
  isSpecialSubregion,
}) {
  return {
    visitorToRaw,
    visitorToNorm: normalize(visitorToRaw),
    requirement,
    allowedStay,
    notes,
    aliasesNorm,
    parentNorm,
    isSpecialSubregion,
  };
}

async function fetchWikiTable() {
  const res = await fetch(WIKI_URL);
  const html = await res.text();
  const rows = [];
  const seen = new Set();

  const tableMatches = [...html.matchAll(/<table[^>]*class="[^"]*wikitable[^"]*"[^>]*>([\s\S]*?)<\/table>/gi)];
  if (!tableMatches.length) {
    throw new Error("Could not find visa requirements wikitable on Wikipedia page");
  }

  const cleanHtml = (value) =>
    cleanDisplayName(
      String(value || "")
        .replace(/<sup[\s\S]*?<\/sup>/gi, " ")
        .replace(/<style[\s\S]*?<\/style>/gi, " ")
        .replace(/<[^>]+>/g, " ")
    );

  for (const tableMatch of tableMatches) {
    const tableHtml = tableMatch[1];
    const rowMatches = [...tableHtml.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gi)];

    for (const rowMatch of rowMatches) {
      const rowHtml = rowMatch[1];
      const isHeaderRow = /<th[\s\S]*<\/th>/i.test(rowHtml) && !/<td/i.test(rowHtml);
      if (isHeaderRow) continue;

      const thName = rowHtml.match(/<th[^>]*>([\s\S]*?)<\/th>/i)?.[1] ?? "";
      const tdCells = [...rowHtml.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gi)].map((cell) => cell[1]);

      if (!thName && tdCells.length < 4) continue;
      if (thName && tdCells.length < 3) continue;

      const visitorTo = cleanHtml(thName || tdCells[0] || "");
      const requirement = cleanHtml(tdCells[thName ? 0 : 1] || "");
      const allowedStay = cleanHtml(tdCells[thName ? 1 : 2] || "");
      const notes = cleanHtml(tdCells[thName ? 2 : 3] || "");

      if (!visitorTo || !requirement) continue;

      const groupedSeeds = findSeedsForGroupedVisitor(visitorTo);
      const shouldExplodeGroupedRow = visitorTo.includes(" - ") && groupedSeeds.length > 0;

      if (shouldExplodeGroupedRow) {
        const parentNorm = normalize(visitorTo.split(" - ")[0]);

        for (const seed of groupedSeeds) {
          const seedLabels = [
            seed.name,
            seed.officialName,
            ...(Array.isArray(seed.aliases) ? seed.aliases : []),
            ...(MANUAL_ALIASES_BY_NORM[normalize(seed.name)] || []),
          ]
            .filter(Boolean)
            .filter((value) => value !== "undefined");

          const aliasesNorm = seedLabels
            .map(cleanDisplayName)
            .map(normalize)
            .filter(Boolean)
            .filter((alias) => alias !== normalize(seed.name))
            .filter((alias, index, array) => array.indexOf(alias) === index);

          const payload = buildRowPayload({
            visitorToRaw: seed.name,
            requirement,
            allowedStay,
            notes,
            aliasesNorm,
            parentNorm,
            isSpecialSubregion: true,
          });

          const fingerprint = [
            payload.visitorToNorm,
            normalize(requirement),
            normalize(allowedStay),
            normalize(notes),
          ].join("|");

          if (seen.has(fingerprint)) continue;
          seen.add(fingerprint);
          rows.push(payload);
        }

        continue;
      }

      const { aliasesNorm, parentNorm, isSpecialSubregion } =
        extractAliases(visitorTo);

      const payload = buildRowPayload({
        visitorToRaw: visitorTo,
        requirement,
        allowedStay,
        notes,
        aliasesNorm,
        parentNorm,
        isSpecialSubregion,
      });

      const fingerprint = [
        payload.visitorToNorm,
        normalize(requirement),
        normalize(allowedStay),
        normalize(notes),
      ].join("|");

      if (seen.has(fingerprint)) continue;
      seen.add(fingerprint);
      rows.push(payload);
    }
  }

  return rows;
}

async function run() {
  console.log("Inside run()");
  console.log("Fetching Wikipedia...");

  const rows = await fetchWikiTable();

  console.log(`Parsed ${rows.length} rows`);

  const latestRuns = await supabaseRest("visa_sync_runs", {
    searchParams: {
      select: "version",
      order: "version.desc",
      limit: "1",
    },
  });

  const latestRun = latestRuns[0] || null;

  const newVersion = (latestRun?.version ?? 0) + 1;

  await supabaseRest("visa_sync_runs", {
    method: "POST",
    body: {
      version: newVersion,
      row_count: rows.length,
    },
  });

  const inserts = rows.map((row) => ({
    visitor_to_raw: row.visitorToRaw,
    visitor_to_norm: row.visitorToNorm,
    requirement: row.requirement,
    allowed_stay: row.allowedStay,
    notes: row.notes,
    aliases_norm: row.aliasesNorm,
    parent_norm: row.parentNorm,
    is_special_subregion: row.isSpecialSubregion,
    version: newVersion,
    source: "wikipedia",
  }));

  await supabaseRest("visa_requirements", {
    method: "POST",
    body: inserts,
  });

  console.log("Sync complete. Version:", newVersion);
}

async function supabaseRest(table, options = {}) {
  const {
    method = "GET",
    searchParams = null,
    body = undefined,
  } = options;

  const url = new URL(`/rest/v1/${table}`, SUPABASE_URL);

  if (searchParams) {
    for (const [key, value] of Object.entries(searchParams)) {
      if (value != null) {
        url.searchParams.set(key, value);
      }
    }
  }

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
  };

  if (method !== "GET") {
    headers["Content-Type"] = "application/json";
    headers["Prefer"] = "return=representation";
  }

  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  const parsed = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(
      `Supabase REST ${method} ${table} failed (${response.status}): ${text}`
    );
  }

  return parsed;
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
