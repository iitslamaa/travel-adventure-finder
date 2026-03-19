# Place Language Override Workflow

This flow replaces the old "paste SQL into Supabase Editor" step.

## Source of truth

- CLDR baseline stays in the raw place-language tables.
- Individually researched app overrides live in:
  - `packages/data/research/place_language_overrides.researched.batch*.json`

Each override row should be reviewed place by place and backed by evidence.

## Apply a new researched batch

1. Add or update the researched batch JSON in `packages/data/research/`.
2. Regenerate the committed override migration:

```bash
cd /Users/lamayassine/travel-af
node scripts/generate-place-language-override-migration.mjs --name place_language_override_batches
```

3. Push the migration to Supabase:

```bash
cd /Users/lamayassine/travel-af
supabase db push
```

No manual SQL Editor paste is required when the researched rows are committed as a migration.

## Review tracker

To rebuild the app-place review tracker:

```bash
cd /Users/lamayassine/travel-af
node scripts/build-place-language-review-tracker.mjs
```

This writes:

- `packages/data/research/place_language_review_tracker.csv`

The tracker is based on the app's current place list from:

- `apps/ios/TravelScoreriOS/countries.geojson`

## Current status

- Reviewed places are marked `reviewed_override`
- Unreviewed places are marked `pending_review`

The tracker is intended to make the worldwide review explicit and auditable rather than inferred by region.
