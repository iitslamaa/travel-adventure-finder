do $$
begin
    if exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'country_language_profiles'
    ) and not exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'country_language_profiles_legacy'
    ) then
        execute 'alter table public.country_language_profiles rename to country_language_profiles_legacy';
    end if;
end
$$;

create table if not exists place_language_profiles_raw (
    place_type text not null,
    place_code text not null,
    source text not null,
    source_version text,
    languages jsonb not null default '[]'::jsonb,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (place_type, place_code, source),
    constraint place_language_profiles_raw_place_type_check
        check (place_type in ('country', 'city')),
    constraint place_language_profiles_raw_languages_is_array
        check (jsonb_typeof(languages) = 'array')
);

create table if not exists place_language_profile_overrides (
    place_type text not null,
    place_code text not null,
    languages jsonb not null default '[]'::jsonb,
    notes text,
    override_reason text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (place_type, place_code),
    constraint place_language_profile_overrides_place_type_check
        check (place_type in ('country', 'city')),
    constraint place_language_profile_overrides_languages_is_array
        check (jsonb_typeof(languages) = 'array')
);

create or replace function touch_place_language_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace function validate_place_language_entries()
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
        raise exception 'languages must be a JSON array';
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

drop trigger if exists place_language_profiles_raw_touch_updated_at on place_language_profiles_raw;
create trigger place_language_profiles_raw_touch_updated_at
before update on place_language_profiles_raw
for each row
execute function touch_place_language_updated_at();

drop trigger if exists place_language_profile_overrides_touch_updated_at on place_language_profile_overrides;
create trigger place_language_profile_overrides_touch_updated_at
before update on place_language_profile_overrides
for each row
execute function touch_place_language_updated_at();

drop trigger if exists place_language_profiles_raw_validate_languages on place_language_profiles_raw;
create trigger place_language_profiles_raw_validate_languages
before insert or update on place_language_profiles_raw
for each row
execute function validate_place_language_entries();

drop trigger if exists place_language_profile_overrides_validate_languages on place_language_profile_overrides;
create trigger place_language_profile_overrides_validate_languages
before insert or update on place_language_profile_overrides
for each row
execute function validate_place_language_entries();

do $$
begin
    if exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'country_language_profiles_legacy'
    ) then
        insert into place_language_profile_overrides (
            place_type,
            place_code,
            languages,
            notes,
            override_reason
        )
        select
            'country' as place_type,
            country_iso2 as place_code,
            languages,
            notes,
            'Migrated from legacy country_language_profiles'
        from country_language_profiles_legacy
        on conflict (place_type, place_code) do nothing;
    end if;
end
$$;

create or replace view place_language_profiles_resolved as
with place_keys as (
    select distinct place_type, place_code
    from place_language_profiles_raw
    union
    select distinct place_type, place_code
    from place_language_profile_overrides
)
select
    place_keys.place_type,
    place_keys.place_code,
    coalesce(override_row.languages, raw_row.languages, '[]'::jsonb) as languages,
    case
        when override_row.place_code is not null then 'override'
        else raw_row.source
    end as source,
    case
        when override_row.place_code is not null then 'manual'
        else raw_row.source_version
    end as source_version,
    coalesce(override_row.notes, raw_row.notes) as notes,
    raw_row.source as baseline_source,
    raw_row.source_version as baseline_source_version,
    (override_row.place_code is not null) as has_override,
    coalesce(override_row.created_at, raw_row.created_at, now()) as created_at,
    greatest(
        coalesce(override_row.updated_at, '-infinity'::timestamptz),
        coalesce(raw_row.updated_at, '-infinity'::timestamptz)
    ) as updated_at
from place_keys
left join lateral (
    select *
    from place_language_profile_overrides o
    where o.place_type = place_keys.place_type
      and o.place_code = place_keys.place_code
) as override_row on true
left join lateral (
    select *
    from place_language_profiles_raw r
    where r.place_type = place_keys.place_type
      and r.place_code = place_keys.place_code
    order by
        case when r.source = 'cldr_territory_language_info' then 0 else 1 end,
        r.updated_at desc
    limit 1
) as raw_row on true;

drop view if exists country_language_profiles;
create view country_language_profiles as
select
    place_code as country_iso2,
    source,
    source_version,
    languages,
    notes,
    baseline_source,
    baseline_source_version,
    has_override,
    created_at,
    updated_at
from place_language_profiles_resolved
where place_type = 'country';

alter table place_language_profiles_raw enable row level security;
alter table place_language_profile_overrides enable row level security;

drop policy if exists "place language raw readable" on place_language_profiles_raw;
create policy "place language raw readable"
on place_language_profiles_raw
for select
to anon, authenticated
using (true);

drop policy if exists "place language overrides readable" on place_language_profile_overrides;
create policy "place language overrides readable"
on place_language_profile_overrides
for select
to anon, authenticated
using (true);

grant select on place_language_profiles_resolved to anon, authenticated;
grant select on country_language_profiles to anon, authenticated;

create index if not exists place_language_profiles_raw_lookup_idx
on place_language_profiles_raw (place_type, place_code);

create index if not exists place_language_profile_overrides_lookup_idx
on place_language_profile_overrides (place_type, place_code);
