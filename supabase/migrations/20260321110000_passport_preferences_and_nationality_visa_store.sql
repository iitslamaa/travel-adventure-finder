create or replace function public.is_uppercase_text_array(input_values text[])
returns boolean
language sql
immutable
as $$
    select not exists (
        select 1
        from unnest(coalesce(input_values, '{}'::text[])) as code
        where code <> upper(code)
    );
$$;

create table if not exists public.user_passport_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    nationality_country_codes text[] not null default '{}'::text[],
    passport_country_code text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint user_passport_preferences_country_codes_uppercase check (
        public.is_uppercase_text_array(nationality_country_codes)
    ),
    constraint user_passport_preferences_passport_country_code_uppercase check (
        passport_country_code is null or passport_country_code = upper(passport_country_code)
    ),
    constraint user_passport_preferences_passport_in_nationalities check (
        passport_country_code is null
        or passport_country_code = any(nationality_country_codes)
    )
);

drop trigger if exists user_passport_preferences_touch_updated_at on public.user_passport_preferences;
create trigger user_passport_preferences_touch_updated_at
before update on public.user_passport_preferences
for each row
execute function touch_language_profile_updated_at();

alter table public.user_passport_preferences enable row level security;

drop policy if exists "user passport preferences select own" on public.user_passport_preferences;
create policy "user passport preferences select own"
on public.user_passport_preferences
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "user passport preferences insert own" on public.user_passport_preferences;
create policy "user passport preferences insert own"
on public.user_passport_preferences
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "user passport preferences update own" on public.user_passport_preferences;
create policy "user passport preferences update own"
on public.user_passport_preferences
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user passport preferences delete own" on public.user_passport_preferences;
create policy "user passport preferences delete own"
on public.user_passport_preferences
for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.user_passport_preferences to authenticated;

alter table public.visa_requirements
add column if not exists passport_from_raw text;

alter table public.visa_requirements
add column if not exists passport_from_norm text;

alter table public.visa_requirements
add column if not exists passport_from_iso2 text;

alter table public.visa_requirements
add column if not exists source_url text;

update public.visa_requirements
set
    passport_from_raw = coalesce(passport_from_raw, 'United States'),
    passport_from_norm = coalesce(passport_from_norm, 'united states'),
    passport_from_iso2 = coalesce(passport_from_iso2, 'US'),
    source_url = coalesce(
        source_url,
        'https://en.wikipedia.org/wiki/Visa_requirements_for_United_States_citizens'
    )
where
    passport_from_raw is null
    or passport_from_norm is null
    or passport_from_iso2 is null
    or source_url is null;

alter table public.visa_requirements
alter column passport_from_raw set not null;

alter table public.visa_requirements
alter column passport_from_norm set not null;

alter table public.visa_requirements
alter column passport_from_iso2 set not null;

create index if not exists visa_requirements_passport_from_iso2_idx
on public.visa_requirements (passport_from_iso2);

create index if not exists visa_requirements_passport_version_idx
on public.visa_requirements (passport_from_iso2, version);

alter table public.visa_sync_runs
add column if not exists passport_from_raw text;

alter table public.visa_sync_runs
add column if not exists passport_from_norm text;

alter table public.visa_sync_runs
add column if not exists passport_from_iso2 text;

alter table public.visa_sync_runs
add column if not exists source_url text;

update public.visa_sync_runs
set
    passport_from_raw = coalesce(passport_from_raw, 'United States'),
    passport_from_norm = coalesce(passport_from_norm, 'united states'),
    passport_from_iso2 = coalesce(passport_from_iso2, 'US'),
    source_url = coalesce(
        source_url,
        'https://en.wikipedia.org/wiki/Visa_requirements_for_United_States_citizens'
    )
where
    passport_from_raw is null
    or passport_from_norm is null
    or passport_from_iso2 is null
    or source_url is null;

alter table public.visa_sync_runs
alter column passport_from_raw set not null;

alter table public.visa_sync_runs
alter column passport_from_norm set not null;

alter table public.visa_sync_runs
alter column passport_from_iso2 set not null;

create index if not exists visa_sync_runs_passport_from_iso2_version_idx
on public.visa_sync_runs (passport_from_iso2, version desc);
