# Language Compatibility Setup

This feature should use one canonical language registry everywhere:

- iOS profile language picker
- future React Native picker
- `profiles.languages[].code`
- `country_language_profiles.languages[].code`

## Canonical IDs

Use lowercase base language codes from `app_languages.code`.

Examples:

- `en`
- `fr`
- `ja`
- `pt`

Do not store display names like `English` or mixed values like `native`.

## Proficiency contract

Store only these values in profile payloads:

- `beginner`
- `conversational`
- `fluent`

Map them like this:

- `beginner` -> `0.0`
- `conversational` -> `0.5`
- `fluent` -> `1.0`

## Place language contract

The long-term model is place-based, not country-only.

Each place profile row stores:

- `place_type`
- `place_code`
- `languages` JSON array

Each language item must include:

- `code`
- `type`
- `coverage`

Allowed `type` values:

- `official`
- `widely_spoken`
- `tourist`
- `minor`

Recommended starting coverage weights:

- `official` -> `1.0`
- `widely_spoken` -> `0.7`
- `tourist` -> `0.35`
- `minor` -> `0.15`

## Data layers

Use three layers:

1. `place_language_profiles_raw`
   Baseline source imports like CLDR.

2. `place_language_profile_overrides`
   Product-layer overrides for traveler reality, tourism usability, and later city-level nuance.

3. `country_language_profiles`
   A resolved country-facing view used by the app today.

Later, city support can use:

- `place_language_profiles_resolved`
  filtered by `place_type = 'city'`

## Getting real baseline data from CLDR

Use CLDR as the authoritative baseline for official territory-language relationships.

Source:

- [CLDR Releases/Downloads](https://cldr.unicode.org/index/downloads)
- [CLDR 48.1 data files](https://www.unicode.org/Public/cldr/48.1/)
- [Territory-Language Information chart](https://www.unicode.org/cldr/charts/latest/supplemental/territory_language_information.html)

Important:

- CLDR gives you official-language baseline data, not traveler-usability data.
- CLDR includes fields like `officialStatus` and `populationPercent`.
- CLDR does not solve tourism English coverage or dialect interchangeability for you.

Generate a baseline import from CLDR:

```bash
cd /Users/lamayassine/travel-af
node scripts/import-cldr-territory-languages.mjs --version 48.1
```

That writes:

- [place_language_profiles.raw.cldr.json](/Users/lamayassine/travel-af/packages/data/seed/place_language_profiles.raw.cldr.json)

Then turn that JSON into raw-layer seed SQL:

```bash
node scripts/generate-place-language-seed.mjs --target raw --input packages/data/seed/place_language_profiles.raw.cldr.json
```

Then run the generated SQL in Supabase:

- [place_language_profiles_raw.sql](/Users/lamayassine/travel-af/supabase/seeds/place_language_profiles_raw.sql)

## Adding overrides for traveler reality

Create your own override file with only researched rows:

```bash
touch /tmp/place_language_profile_overrides.real.json
open /tmp/place_language_profile_overrides.real.json
```

The file should contain an array of rows shaped like:

```json
[
  {
    "place_type": "country",
    "place_code": "LB",
    "override_reason": "dialect_and_traveler_usability_override",
    "notes": "Explain why this override exists and what evidence supports it.",
    "languages": [
      { "code": "apc", "type": "widely_spoken", "coverage": 1.0 },
      { "code": "en", "type": "widely_spoken", "coverage": 0.5 }
    ],
    "evidence": [
      {
        "kind": "official_tourism",
        "title": "Source title",
        "url": "https://example.com",
        "note": "Short explanation of why this source supports the override."
      }
    ]
  }
]
```

Then generate SQL:

```bash
node scripts/generate-place-language-seed.mjs --target overrides --input /tmp/place_language_profile_overrides.real.json
```

Then run:

- [place_language_profile_overrides.sql](/Users/lamayassine/travel-af/supabase/seeds/place_language_profile_overrides.sql)

An initial researched override batch lives here:

- [place_language_overrides.researched.batch1.json](/Users/lamayassine/travel-af/packages/data/research/place_language_overrides.researched.batch1.json)

Suggested workflow:

1. Import CLDR baseline into `raw`.
2. Review high-priority countries.
3. Add overrides for travel-usability and dialect exceptions.
4. Let the resolved country view power the app.

## Scoring rule

For each user language:

`compatibility = proficiency_multiplier * country_coverage`

Take the max compatibility across all user languages.

Version 1 matching rule:

- exact language-code matches only
- no automatic dialect fallback
- no automatic macro-language family matching

Normalize:

- `>= 0.65` -> `100`
- `>= 0.30` -> `50`
- `< 0.30` -> `0`

## Supabase steps

1. Apply the migration in [20260318123000_language_compatibility_foundation.sql](/Users/lamayassine/travel-af/supabase/migrations/20260318123000_language_compatibility_foundation.sql).

2. Generate the canonical language seed:

```bash
node scripts/generate-language-catalog-seed.mjs
```

3. Apply the generated seed in [app_languages.sql](/Users/lamayassine/travel-af/supabase/seeds/app_languages.sql).

4. Copy [country_language_profiles.template.json](/Users/lamayassine/travel-af/packages/data/seed/country_language_profiles.template.json) into a real dataset file and expand it country by country.

5. Generate the country profile seed:

```bash
node scripts/generate-country-language-profile-seed.mjs /absolute/path/to/your-country-language-profiles.json
```

6. Apply the generated seed in [country_language_profiles.sql](/Users/lamayassine/travel-af/supabase/seeds/country_language_profiles.sql).

7. Verify:

```sql
select count(*) from app_languages;
select country_iso2, languages
from country_language_profiles
order by country_iso2
limit 10;
```

## Data-entry rules

- Always use `app_languages.code` values for country language rows.
- Keep coverage country-level for now.
- Use manual overrides for traveler expectation, not only official-language purity.
- Start with top destination countries first and grow the dataset incrementally.

## Recommended rollout

1. Ship canonical language IDs and proficiency cleanup in iOS.
2. Seed `app_languages`.
3. Seed top 25-50 `country_language_profiles`.
4. Add the iOS card and scorer against this table.
5. Reuse the same table and payload shape in React Native later.
