#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { localizedStringState, requiredLocales } from "./ios-localization-config.mjs";

const root = process.cwd();
const catalogPaths = [
  path.join(root, "apps/ios/TravelScoreriOS/App/Resources/Localizable.xcstrings"),
  path.join(root, "apps/ios/TravelScoreriOS/App/Resources/InfoPlist.xcstrings"),
];

let updated = 0;

for (const catalogPath of catalogPaths) {
  const raw = await fs.readFile(catalogPath, "utf8");
  const catalog = JSON.parse(raw);

  for (const entry of Object.values(catalog.strings ?? {})) {
    for (const locale of requiredLocales) {
      if (locale === "en") continue;
      const stringUnit = entry.localizations?.[locale]?.stringUnit;
      if (!stringUnit?.value) continue;

      const nextState = localizedStringState(locale);
      if (stringUnit.state === nextState) continue;

      stringUnit.state = nextState;
      updated += 1;
    }
  }

  await fs.writeFile(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
}

console.log(`synced ${updated} localization states`);
