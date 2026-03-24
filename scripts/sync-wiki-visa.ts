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
const PASSPORT_VISA_SOURCES = require("./data/passport_visa_sources.json");
const fs = require("fs");
const path = require("path");

console.log("Starting visa sync script...");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

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
  turkiye: ["turkey"],
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

const argv = process.argv.slice(2);
const hasFlag = (flag) => argv.includes(flag);
const getArgValue = (name) => {
  const directPrefix = `--${name}=`;
  const direct = argv.find((arg) => arg.startsWith(directPrefix));
  if (direct) return direct.slice(directPrefix.length);

  const index = argv.indexOf(`--${name}`);
  if (index !== -1 && argv[index + 1] && !argv[index + 1].startsWith("--")) {
    return argv[index + 1];
  }

  return null;
};

const DEFAULT_UNRESOLVED_REPORT_PATH = path.join(
  __dirname,
  "data",
  "passport_visa_unresolved.json"
);
const DEFAULT_MANIFEST_OUTPUT_PATH = path.join(
  __dirname,
  "data",
  "passport_visa_sources.generated.json"
);
const WIKIPEDIA_HEADERS = {
  "User-Agent": "travel-af-codex/1.0 (passport visa sync)",
  "Accept": "application/json,text/html;q=0.9,*/*;q=0.8",
};
const PASSPORT_SELECTION_EXCLUDED_ISO2 = new Set(["AQ", "BV", "HM"]);

function seedForPassportIso2(iso2) {
  return COUNTRY_SEEDS.find(
    (seed) => String(seed.iso2 || "").toUpperCase() === String(iso2 || "").toUpperCase()
  ) || null;
}

function passportLabelsForSeed(seed) {
  if (!seed) return [];

  return [
    seed.name,
    seed.officialName,
    ...(Array.isArray(seed.aliases) ? seed.aliases : []),
  ]
    .filter(Boolean)
    .filter((value) => value !== "undefined")
    .map((value) => cleanDisplayName(value))
    .filter(Boolean)
    .filter((value, index, array) => array.indexOf(value) === index);
}

function stripHtml(value) {
  return cleanDisplayName(
    String(value || "")
      .replace(/<sup[\s\S]*?<\/sup>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
  );
}

async function fetchPageLeadText(pageUrl) {
  const response = await fetch(pageUrl, { headers: WIKIPEDIA_HEADERS });
  if (!response.ok) {
    return "";
  }

  const html = await response.text();
  const leadSection = html.match(/<div class="mw-content-ltr[\s\S]*?<\/table>/i)
    ? html
    : html;

  const paragraphs = [...leadSection.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)]
    .slice(0, 4)
    .map((match) => stripHtml(match[1]))
    .filter(Boolean);

  return normalize(paragraphs.join(" "));
}

function searchTextMatchesSeed(text, seed) {
  const normalizedText = normalize(text || "");
  if (!normalizedText) return false;

  const labels = new Set(
    passportLabelsForSeed(seed)
      .map((label) => normalize(label))
      .filter(Boolean)
  );

  return [...labels].some((label) => {
    if (label.length < 4) return false;
    return normalizedText.includes(label);
  });
}

async function candidateMatchesSeed(candidateTitle, seed) {
  if (searchTextMatchesSeed(candidateTitle, seed)) {
    return true;
  }

  const pageUrl = `https://en.wikipedia.org/wiki/${encodeURIComponent(candidateTitle.replace(/\s+/g, "_"))}`;
  const leadText = await fetchPageLeadText(pageUrl);
  return searchTextMatchesSeed(leadText, seed);
}

async function resolveWikipediaSource(seed, explicitUrl) {
  if (explicitUrl) {
    return {
      url: explicitUrl,
      title: explicitUrl.split("/wiki/")[1] || explicitUrl,
    };
  }

  const iso2 = String(seed?.iso2 || "").toUpperCase();
  const manifestSource = PASSPORT_VISA_SOURCES[iso2];
  if (manifestSource?.url) {
    const url = manifestSource.url;
    return {
      url,
      title: manifestSource.title || url.split("/wiki/")[1] || url,
    };
  }

  const labels = passportLabelsForSeed(seed);
  for (const label of labels) {
    const searchQueries = [
      `Visa requirements for ${label} citizens`,
      `Visa requirements for citizens of ${label}`,
      `Visa requirements for ${label} nationals`,
      `${label} passport visa requirements`,
    ];

    for (const searchQuery of searchQueries) {
      const searchUrl = new URL("https://en.wikipedia.org/w/api.php");
      searchUrl.searchParams.set("action", "query");
      searchUrl.searchParams.set("list", "search");
      searchUrl.searchParams.set("format", "json");
      searchUrl.searchParams.set("utf8", "1");
      searchUrl.searchParams.set("srsearch", searchQuery);
      searchUrl.searchParams.set("srlimit", "10");

      const response = await fetch(searchUrl, { headers: WIKIPEDIA_HEADERS });
      if (!response.ok) continue;

      const payload = await response.json();
      const candidates = Array.isArray(payload?.query?.search)
        ? payload.query.search
        : [];

      for (const candidate of candidates) {
        const title = String(candidate?.title || "");
        if (
          !/^Visa requirements for /i.test(title) ||
          !/(citizens|nationals|passport holders?)/i.test(title)
        ) {
          continue;
        }

        if (!(await candidateMatchesSeed(title, seed))) {
          continue;
        }

        return {
          title,
          url: `https://en.wikipedia.org/wiki/${encodeURIComponent(title.replace(/\s+/g, "_"))}`,
        };
      }
    }
  }

  throw new Error(
    `Could not resolve Wikipedia visa page for ${seed?.name || iso2 || "unknown passport"}`
  );
}

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

async function fetchWikiTable(wikiUrl) {
  const res = await fetch(wikiUrl, { headers: WIKIPEDIA_HEADERS });
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

async function syncPassport({ seed, wikiUrl, wikiTitle }) {
  console.log(`Fetching Wikipedia for ${seed.name} (${seed.iso2})...`);
  const rows = await fetchWikiTable(wikiUrl);
  console.log(`Parsed ${rows.length} rows for ${seed.iso2}`);

  const latestRuns = await supabaseRest("visa_sync_runs", {
    searchParams: {
      select: "version",
      passport_from_iso2: `eq.${seed.iso2.toUpperCase()}`,
      order: "version.desc",
      limit: "1",
    },
  });

  const latestRun = latestRuns[0] || null;

  const newVersion = (latestRun?.version ?? 0) + 1;

  await supabaseRest("visa_sync_runs", {
    method: "POST",
    body: {
      passport_from_raw: seed.name,
      passport_from_norm: normalize(seed.name),
      passport_from_iso2: seed.iso2.toUpperCase(),
      source_url: wikiUrl,
      version: newVersion,
      row_count: rows.length,
    },
  });

  const inserts = rows.map((row) => ({
    passport_from_raw: seed.name,
    passport_from_norm: normalize(seed.name),
    passport_from_iso2: seed.iso2.toUpperCase(),
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
    source_url: wikiUrl,
  }));

  await supabaseRest("visa_requirements", {
    method: "POST",
    body: inserts,
  });

  console.log(
    `Sync complete for ${seed.iso2} using ${wikiTitle || wikiUrl}. Version: ${newVersion}`
  );
}

function writeUnresolvedReport(unresolved, reportPath = DEFAULT_UNRESOLVED_REPORT_PATH) {
  const payload = {
    generatedAt: new Date().toISOString(),
    count: unresolved.length,
    unresolved,
  };

  fs.writeFileSync(reportPath, JSON.stringify(payload, null, 2) + "\n", "utf8");
  console.log(`Wrote unresolved passport visa report to ${reportPath}`);
}

function writeResolvedManifest(resolvedSources, outputPath = DEFAULT_MANIFEST_OUTPUT_PATH) {
  const sorted = Object.fromEntries(
    Object.entries(resolvedSources).sort(([left], [right]) =>
      left.localeCompare(right)
    )
  );

  fs.writeFileSync(outputPath, JSON.stringify(sorted, null, 2) + "\n", "utf8");
  console.log(`Wrote resolved passport visa manifest to ${outputPath}`);
}

async function run() {
  console.log("Inside run()");

  const explicitPassportIso2 = (getArgValue("passport-iso2") || getArgValue("iso2") || "US").toUpperCase();
  const explicitWikiUrl = getArgValue("wiki-url");
  const syncAll = hasFlag("--all");
  const sovereignOnly = hasFlag("--sovereign-only");
  const skipMissing = hasFlag("--skip-missing");
  const writeUnresolved = hasFlag("--write-unresolved");
  const resolveOnly = hasFlag("--resolve-only");
  const writeManifest = hasFlag("--write-manifest");
  const unresolvedReportPath = getArgValue("unresolved-report") || DEFAULT_UNRESOLVED_REPORT_PATH;
  const manifestOutputPath = getArgValue("manifest-output") || DEFAULT_MANIFEST_OUTPUT_PATH;
  const limitValue = Number(getArgValue("limit") || 0);
  const passportSeeds = syncAll
    ? COUNTRY_SEEDS
        .filter((seed) => !sovereignOnly || seed?.territory !== true)
        .filter((seed) => !PASSPORT_SELECTION_EXCLUDED_ISO2.has(String(seed?.iso2 || "").toUpperCase()))
        .filter((seed) => seed?.iso2 && seed?.name)
        .slice(0, limitValue > 0 ? limitValue : COUNTRY_SEEDS.length)
    : [seedForPassportIso2(explicitPassportIso2)].filter(Boolean);

  if (!passportSeeds.length) {
    throw new Error(`Unknown passport iso2: ${explicitPassportIso2}`);
  }

  const unresolved = [];
  const resolvedSources = {};

  for (const seed of passportSeeds) {
    let source;
    try {
      source = await resolveWikipediaSource(seed, explicitWikiUrl);
    } catch (error) {
      const failure = {
        iso2: seed.iso2,
        name: seed.name,
        error: error instanceof Error ? error.message : String(error),
      };

      unresolved.push(failure);
      console.warn(`Skipping ${seed.iso2}: ${failure.error}`);

      if (!skipMissing) {
        throw error;
      }

      continue;
    }

    resolvedSources[seed.iso2.toUpperCase()] = {
      title: source.title,
      url: source.url,
    };

    if (resolveOnly) {
      console.log(`Resolved ${seed.iso2}: ${source.url}`);
      continue;
    }

    await syncPassport({
      seed,
      wikiUrl: source.url,
      wikiTitle: source.title,
    });
  }

  if (writeUnresolved || unresolved.length > 0) {
    writeUnresolvedReport(unresolved, unresolvedReportPath);
  }

  if (writeManifest || resolveOnly) {
    writeResolvedManifest(resolvedSources, manifestOutputPath);
  }

  if (unresolved.length > 0 && !skipMissing) {
    throw new Error(
      `Unresolved ${unresolved.length} passport source(s). Re-run with --skip-missing to continue and emit a report.`
    );
  }
}

/**
 * @param {string} table
 * @param {{
 *   method?: string,
 *   searchParams?: Record<string, string | number | null | undefined> | null,
 *   body?: unknown
 * }} [options]
 */
async function supabaseRest(table, options = {}) {
  /** @type {string} */
  const method =
    options && typeof options === "object" && "method" in options && options.method
      ? String(options.method)
      : "GET";
  const searchParams =
    options && typeof options === "object" && "searchParams" in options
      ? options.searchParams
      : null;
  const body =
    options && typeof options === "object" && "body" in options
      ? options.body
      : undefined;

  const url = new URL(`/rest/v1/${table}`, SUPABASE_URL);

  if (searchParams) {
    for (const [key, value] of Object.entries(searchParams)) {
      if (value != null) {
        url.searchParams.set(key, String(value));
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
