create table if not exists app_languages (
    code text primary key,
    base_code text not null,
    display_name text not null,
    source text not null default 'iana-subtag-registry',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint app_languages_code_lowercase check (code = lower(code)),
    constraint app_languages_base_code_lowercase check (base_code = lower(base_code))
);

create table if not exists country_language_profiles (
    country_iso2 text primary key,
    source text not null default 'manual_cldr_hybrid',
    source_version text,
    languages jsonb not null default '[]'::jsonb,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint country_language_profiles_iso2_uppercase check (country_iso2 = upper(country_iso2)),
    constraint country_language_profiles_languages_is_array check (jsonb_typeof(languages) = 'array')
);

create or replace function touch_language_profile_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace function validate_country_language_profile_languages()
returns trigger
language plpgsql
as $$
declare
    language_entry jsonb;
    language_code text;
    language_type text;
    coverage numeric;
begin
    if jsonb_typeof(new.languages) <> 'array' then
        raise exception 'country_language_profiles.languages must be a JSON array';
    end if;

    for language_entry in
        select value
        from jsonb_array_elements(new.languages)
    loop
        language_code := lower(coalesce(language_entry->>'code', ''));
        language_type := coalesce(language_entry->>'type', '');
        coverage := nullif(language_entry->>'coverage', '')::numeric;

        if language_code = '' then
            raise exception 'Each language entry must include a code';
        end if;

        if not exists (
            select 1
            from app_languages
            where code = language_code
        ) then
            raise exception 'Unknown app language code: %', language_code;
        end if;

        if language_type not in ('official', 'widely_spoken', 'tourist', 'minor') then
            raise exception 'Invalid language type: %', language_type;
        end if;

        if coverage is null or coverage < 0 or coverage > 1 then
            raise exception 'Language coverage must be between 0 and 1 for code %', language_code;
        end if;
    end loop;

    return new;
end;
$$;

drop trigger if exists app_languages_touch_updated_at on app_languages;
create trigger app_languages_touch_updated_at
before update on app_languages
for each row
execute function touch_language_profile_updated_at();

drop trigger if exists country_language_profiles_touch_updated_at on country_language_profiles;
create trigger country_language_profiles_touch_updated_at
before update on country_language_profiles
for each row
execute function touch_language_profile_updated_at();

drop trigger if exists country_language_profiles_validate_languages on country_language_profiles;
create trigger country_language_profiles_validate_languages
before insert or update on country_language_profiles
for each row
execute function validate_country_language_profile_languages();

alter table app_languages enable row level security;
alter table country_language_profiles enable row level security;

drop policy if exists "app languages readable" on app_languages;
create policy "app languages readable"
on app_languages
for select
to anon, authenticated
using (true);

drop policy if exists "country language profiles readable" on country_language_profiles;
create policy "country language profiles readable"
on country_language_profiles
for select
to anon, authenticated
using (true);

create index if not exists country_language_profiles_source_idx
on country_language_profiles (source);
