grant usage on schema public to anon, authenticated;
grant select on public.media_guides to anon, authenticated;

create table if not exists public.media_podcast_episodes (
    id uuid primary key default gen_random_uuid(),
    slug text not null,
    locale text not null default 'en',
    status text not null default 'draft',
    title text not null,
    subtitle text,
    description text,
    season_number integer,
    episode_number integer,
    duration_seconds integer,
    audio_url text,
    external_url text,
    cover_image_url text,
    transcript_markdown text,
    tags text[] not null default '{}',
    sort_order integer not null default 0,
    published_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint media_podcast_episodes_slug_locale_key unique (slug, locale),
    constraint media_podcast_episodes_status_check check (status in ('draft', 'published', 'archived')),
    constraint media_podcast_episodes_locale_check check (locale = lower(locale)),
    constraint media_podcast_episodes_duration_check check (duration_seconds is null or duration_seconds >= 0),
    constraint media_podcast_episodes_episode_check check (episode_number is null or episode_number > 0),
    constraint media_podcast_episodes_season_check check (season_number is null or season_number > 0)
);

create index if not exists media_podcast_episodes_published_idx
    on public.media_podcast_episodes (status, locale, sort_order, published_at desc);

drop trigger if exists media_podcast_episodes_touch_updated_at on public.media_podcast_episodes;
create trigger media_podcast_episodes_touch_updated_at
before update on public.media_podcast_episodes
for each row
execute function public.touch_media_guides_updated_at();

alter table public.media_podcast_episodes enable row level security;

drop policy if exists "Public can read published podcast episodes" on public.media_podcast_episodes;
create policy "Public can read published podcast episodes"
on public.media_podcast_episodes
for select
using (
    status = 'published'
    and coalesce(published_at, now()) <= now()
);

grant select on public.media_podcast_episodes to anon, authenticated;
