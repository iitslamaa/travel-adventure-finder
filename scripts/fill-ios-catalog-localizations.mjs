#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";
import { localizedStringState } from "./ios-localization-config.mjs";

const require = createRequire(import.meta.url);
const { translate } = require("/tmp/country-translate-tool/node_modules/@vitalets/google-translate-api");
const bing = require("/tmp/country-translate-tool/node_modules/bing-translate-api");

const localeMap = new Map([
  ["nl", { google: "nl", bing: "nl" }],
  ["ar", { google: "ar", bing: "ar" }],
  ["ja", { google: "ja", bing: "ja" }],
  ["ko", { google: "ko", bing: "ko" }],
  ["zh-Hans", { google: "zh-CN", bing: "zh-Hans" }],
  ["hi", { google: "hi", bing: "hi" }],
  ["tr", { google: "tr", bing: "tr" }],
  ["pl", { google: "pl", bing: "pl" }],
  ["he", { google: "iw", bing: "he" }],
  ["sv", { google: "sv", bing: "sv" }],
  ["fi", { google: "fi", bing: "fi" }],
  ["da", { google: "da", bing: "da" }],
  ["el", { google: "el", bing: "el" }],
  ["id", { google: "id", bing: "id" }],
  ["uk", { google: "uk", bing: "uk" }],
  ["zh-Hant", { google: "zh-TW", bing: "zh-Hant" }],
  ["ms", { google: "ms", bing: "ms" }],
  ["ro", { google: "ro", bing: "ro" }],
  ["th", { google: "th", bing: "th" }],
  ["vi", { google: "vi", bing: "vi" }],
  ["cs", { google: "cs", bing: "cs" }],
  ["hu", { google: "hu", bing: "hu" }],
]);

const root = process.cwd();
const catalogPaths = [
  path.join(root, "apps/ios/TravelScoreriOS/App/Resources/Localizable.xcstrings"),
  path.join(root, "apps/ios/TravelScoreriOS/App/Resources/InfoPlist.xcstrings"),
];
const dryRun = process.argv.includes("--dry-run");
let googleRateLimitedUntil = 0;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function chunk(values, size) {
  const out = [];
  for (let index = 0; index < values.length; index += size) {
    out.push(values.slice(index, index + size));
  }
  return out;
}

async function googleTranslate(source, target) {
  const result = await translate(source, { from: "en", to: target });
  return result.text.trim();
}

async function bingTranslate(source, target, attempt = 1) {
  try {
    const result = await bing.translate(source, "en", target, true);
    return result.translation.trim();
  } catch (error) {
    if (attempt >= 4) {
      throw error;
    }
    await sleep(1000 * attempt);
    return bingTranslate(source, target, attempt + 1);
  }
}

async function translateWithFallback(source, targets) {
  if (Date.now() >= googleRateLimitedUntil) {
    try {
      return await googleTranslate(source, targets.google);
    } catch (error) {
      const message = String(error);
      if (message.includes("TooManyRequestsError")) {
        googleRateLimitedUntil = Date.now() + 10 * 60 * 1000;
        console.warn("google rate-limited; cooling down for 10 minutes");
      } else {
        console.warn(`google failed (${targets.google}): ${message}`);
      }
    }
  }

  return bingTranslate(source, targets.bing);
}

function* entriesForCatalog(catalog) {
  for (const [key, entry] of Object.entries(catalog.strings ?? {})) {
    if (key.startsWith("country.description.")) continue;
    const english = entry.localizations?.en?.stringUnit?.value?.trim();
    if (!english) continue;
    yield [key, entry, english];
  }
}

async function fillCatalog(catalogPath) {
  const raw = await fs.readFile(catalogPath, "utf8");
  const catalog = JSON.parse(raw);
  let updated = 0;

  for (const [locale, targets] of localeMap) {
    const missing = [];

    for (const [key, entry, english] of entriesForCatalog(catalog)) {
      const current = entry.localizations?.[locale]?.stringUnit?.value;
      if (!current || !String(current).trim()) {
        missing.push({ key, english });
      }
    }

    console.log(`${path.basename(catalogPath)} :: ${locale}: ${missing.length} missing translations`);

    for (const group of chunk(missing, 4)) {
      const translated = await Promise.all(
        group.map(async ({ key, english }) => ({
          key,
          text: await translateWithFallback(english, targets),
        }))
      );

      for (const { key, text } of translated) {
        if (!dryRun) {
          const entry = catalog.strings[key];
          entry.localizations ??= {};
          entry.localizations[locale] = {
            stringUnit: {
              state: localizedStringState(locale),
              value: text,
            },
          };
        }
        updated += 1;
      }

      if (!dryRun) {
        await fs.writeFile(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
      }

      console.log(`${path.basename(catalogPath)} :: ${locale}: ${updated} translated so far`);
      await sleep(250);
    }
  }
}

for (const catalogPath of catalogPaths) {
  await fillCatalog(catalogPath);
}
