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
  ["fr", { google: "fr", bing: "fr" }],
  ["es", { google: "es", bing: "es" }],
  ["de", { google: "de", bing: "de" }],
  ["it", { google: "it", bing: "it" }],
  ["pt-BR", { google: "pt", bing: "pt" }],
  ["ru", { google: "ru", bing: "ru" }],
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
const catalogPath = path.join(
  root,
  "apps/ios/TravelScoreriOS/App/Resources/Localizable.xcstrings"
);

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
        console.warn(`google rate-limited; cooling down for 10 minutes`);
      } else {
        console.warn(`google failed (${targets.google}): ${message}`);
      }
    }
  }

  return bingTranslate(source, targets.bing);
}

async function main() {
  const raw = await fs.readFile(catalogPath, "utf8");
  const catalog = JSON.parse(raw);
  const entries = Object.entries(catalog.strings).filter(([key]) =>
    key.startsWith("country.description.")
  );

  let updated = 0;

  for (const [locale, targets] of localeMap) {
    const missing = entries
      .filter(([, entry]) => {
        const value = entry.localizations?.[locale]?.stringUnit?.value;
        return !(typeof value === "string" && value.trim().length > 0);
      })
      .map(([key, entry]) => ({
        key,
        source: entry.localizations?.en?.stringUnit?.value?.trim(),
      }))
      .filter((item) => item.source);

    console.log(`${locale}: ${missing.length} missing translations`);

    for (const group of chunk(missing, 4)) {
      const translated = await Promise.all(
        group.map(async ({ key, source }) => ({
          key,
          text: await translateWithFallback(source, targets),
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
        console.log(`${locale}: ${updated} translated so far`);
      }

      if (!dryRun) {
        await fs.writeFile(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
      }

      await sleep(250);
    }
  }

  if (!dryRun) {
    await fs.writeFile(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
  }

  console.log(`done: ${updated} translations`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
