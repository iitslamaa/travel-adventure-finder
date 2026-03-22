import fs from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();
const iosRoot = path.join(repoRoot, "apps/ios/TravelScoreriOS");
const sourceRoots = [
  path.join(iosRoot, "App"),
  path.join(iosRoot, "Core"),
  path.join(iosRoot, "Features"),
  path.join(iosRoot, "Shared"),
];
const localizablePath = path.join(iosRoot, "App/Resources/Localizable.xcstrings");
const infoPlistPath = path.join(iosRoot, "App/Resources/InfoPlist.xcstrings");
const requiredLocales = ["en", "es", "fr", "de", "it", "pt-BR"];

const keyPatterns = [
  /String\(localized:\s*"([^"]+)"/g,
  /\bText\("([a-z0-9_.-]+)"\)/g,
  /\bButton\("([a-z0-9_.-]+)"\)/g,
  /\bLabel\("([a-z0-9_.-]+)"/g,
  /\bToggle\("([a-z0-9_.-]+)"/g,
  /\bTextField\("([a-z0-9_.-]+)"/g,
  /\bPicker\("([a-z0-9_.-]+)"/g,
];
const dottedKeyPattern = /^[a-z0-9_-]+(\.[a-z0-9_-]+)+$/i;
function walk(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name.includes("Preview")) continue;
      results.push(...walk(fullPath));
      continue;
    }
    if (entry.isFile() && fullPath.endsWith(".swift")) {
      results.push(fullPath);
    }
  }
  return results;
}

function loadCatalog(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8")).strings ?? {};
}

function getUsedKeys(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const keys = new Set();

  for (const pattern of keyPatterns) {
    pattern.lastIndex = 0;
    let match;
    while ((match = pattern.exec(text)) !== null) {
      keys.add(match[1]);
    }
  }

  return [...keys];
}

const localizable = loadCatalog(localizablePath);
const infoPlist = loadCatalog(infoPlistPath);

const keyUsages = new Map();
for (const root of sourceRoots) {
  for (const filePath of walk(root)) {
    for (const key of getUsedKeys(filePath)) {
      const relativePath = path.relative(repoRoot, filePath);
      const usages = keyUsages.get(key) ?? [];
      usages.push(relativePath);
      keyUsages.set(key, usages);
    }
  }
}

const missingKeys = [];
for (const [key, usages] of [...keyUsages.entries()].sort(([a], [b]) => a.localeCompare(b))) {
  if (!localizable[key]) {
    missingKeys.push({ key, usages });
  }
}

const missingLocalizations = [];
for (const [catalogName, catalog] of [
  ["Localizable.xcstrings", localizable],
  ["InfoPlist.xcstrings", infoPlist],
]) {
  for (const [key, entry] of Object.entries(catalog)) {
    const localizations = entry.localizations ?? {};
    if (!keyUsages.has(key) && !dottedKeyPattern.test(key)) {
      continue;
    }
    for (const locale of requiredLocales) {
      const value = localizations[locale]?.stringUnit?.value;
      if (!value) {
        missingLocalizations.push({ catalogName, key, locale });
      }
    }
  }
}

if (missingKeys.length === 0 && missingLocalizations.length === 0) {
  console.log("iOS localization check passed.");
  process.exit(0);
}

if (missingKeys.length > 0) {
  console.log("Missing Localizable.xcstrings keys:");
  for (const { key, usages } of missingKeys) {
    console.log(`- ${key}`);
    for (const usage of usages) {
      console.log(`  ${usage}`);
    }
  }
}

if (missingLocalizations.length > 0) {
  console.log("Missing catalog localizations:");
  for (const { catalogName, key, locale } of missingLocalizations) {
    console.log(`- ${catalogName} :: ${key} :: ${locale}`);
  }
}

process.exit(1);
