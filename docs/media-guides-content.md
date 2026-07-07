# Media Content

The iOS media tab reads guides and podcast episodes from Supabase instead of shipping media cards in the app binary. This lets the team publish, reorder, update, schedule, or archive media without an App Store release.

## Guide Model

Guides live in `public.media_guides`.

- `slug`: Stable cross-platform identifier for one guide.
- `locale`: Lowercase BCP 47 locale, such as `en`, `fr`, or `pt-br`. Use one row per locale.
- `status`: `draft`, `published`, or `archived`.
- `title`, `subtitle`, `excerpt`: Card and summary copy.
- `body_markdown`: Optional in-app article body for a future native detail renderer.
- `external_url`: Optional hosted guide URL. The iOS app opens this when present.
- `cover_image_url`: Optional remote card image.
- `category`: Defaults to `guide`.
- `country_iso2`: Optional uppercase destination code.
- `tags`: Optional tags for future filtering.
- `sort_order`: Manual editorial order.
- `published_at`: Optional schedule time. Published rows with a future timestamp are hidden by RLS.

## Publishing Workflow

Create or edit rows in Supabase Studio or any future CMS connected to the same table. Public clients can only read rows where `status = 'published'` and `published_at` is blank or in the past. There are no public write policies, so app users cannot create or modify guide content.

The React Native app can inherit the same contract by querying `media_guides` with the user's preferred locale plus `en`, then de-duping by `slug` in favor of the best locale match.

## Podcast Model

Podcast episodes live in `public.media_podcast_episodes`.

- `slug`: Stable cross-platform identifier for one episode.
- `locale`: Lowercase BCP 47 locale, such as `en`, `fr`, or `pt-br`. Use one row per locale.
- `status`: `draft`, `published`, or `archived`.
- `title`, `subtitle`, `description`: Card and summary copy.
- `audio_url`: Optional direct audio URL.
- `external_url`: Optional episode page or podcast platform URL.
- `cover_image_url`: Optional remote episode artwork.
- `transcript_markdown`: Optional transcript for a future native detail renderer.
- `season_number`, `episode_number`, `duration_seconds`: Optional episode metadata.
- `tags`: Optional tags for future filtering.
- `sort_order`: Manual editorial order.
- `published_at`: Optional schedule time. Published rows with a future timestamp are hidden by RLS.

The React Native app can use the same locale fallback and `slug` de-dupe logic for `media_podcast_episodes`.
