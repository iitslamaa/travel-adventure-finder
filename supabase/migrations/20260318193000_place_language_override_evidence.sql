alter table if exists place_language_profile_overrides
add column if not exists evidence jsonb not null default '[]'::jsonb;

alter table if exists place_language_profile_overrides
drop constraint if exists place_language_profile_overrides_evidence_is_array;

alter table if exists place_language_profile_overrides
add constraint place_language_profile_overrides_evidence_is_array
check (jsonb_typeof(evidence) = 'array');

drop view if exists country_language_profiles;
drop view if exists place_language_profiles_resolved;

create view place_language_profiles_resolved as
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
    override_row.override_reason,
    override_row.evidence,
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

create view country_language_profiles as
select
    place_code as country_iso2,
    source,
    source_version,
    languages,
    notes,
    override_reason,
    evidence,
    baseline_source,
    baseline_source_version,
    has_override,
    created_at,
    updated_at
from place_language_profiles_resolved
where place_type = 'country';
