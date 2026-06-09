create table if not exists public.media_guides (
    id uuid primary key default gen_random_uuid(),
    slug text not null,
    locale text not null default 'en',
    status text not null default 'draft',
    title text not null,
    subtitle text,
    excerpt text,
    body_markdown text,
    category text not null default 'guide',
    country_iso2 text,
    cover_image_url text,
    external_url text,
    tags text[] not null default '{}',
    sort_order integer not null default 0,
    published_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint media_guides_slug_locale_key unique (slug, locale),
    constraint media_guides_status_check check (status in ('draft', 'published', 'archived')),
    constraint media_guides_locale_check check (locale = lower(locale)),
    constraint media_guides_country_iso2_check check (country_iso2 is null or country_iso2 = upper(country_iso2))
);

create index if not exists media_guides_published_idx
    on public.media_guides (status, locale, sort_order, published_at desc);

create index if not exists media_guides_country_idx
    on public.media_guides (country_iso2)
    where country_iso2 is not null;

create or replace function public.touch_media_guides_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists media_guides_touch_updated_at on public.media_guides;
create trigger media_guides_touch_updated_at
before update on public.media_guides
for each row
execute function public.touch_media_guides_updated_at();

alter table public.media_guides enable row level security;

drop policy if exists "Public can read published media guides" on public.media_guides;
create policy "Public can read published media guides"
on public.media_guides
for select
using (
    status = 'published'
    and coalesce(published_at, now()) <= now()
);
