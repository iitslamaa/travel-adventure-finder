create or replace function public.record_profile_activity_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    added_favorite_country text;
    normalized_home_countries text[];
begin
    if old.current_country is distinct from new.current_country
        and new.current_country is not null
        and btrim(new.current_country) <> ''
    then
        insert into public.activity_events (actor_user_id, event_type, metadata)
        values (
            new.id,
            'current_country_changed',
            jsonb_build_object('country_code', upper(new.current_country))
        );
    end if;

    if old.next_destination is distinct from new.next_destination
        and new.next_destination is not null
        and btrim(new.next_destination) <> ''
    then
        insert into public.activity_events (actor_user_id, event_type, metadata)
        values (
            new.id,
            'next_destination_changed',
            jsonb_build_object('country_code', upper(new.next_destination))
        );
    end if;

    select array_agg(distinct upper(country_code) order by upper(country_code))
    into normalized_home_countries
    from unnest(coalesce(new.lived_countries, array[]::text[])) as country_code
    where btrim(country_code) <> '';

    if old.lived_countries is distinct from new.lived_countries
        and normalized_home_countries is not null
        and array_length(normalized_home_countries, 1) is not null
    then
        insert into public.activity_events (actor_user_id, event_type, metadata)
        values (
            new.id,
            'home_country_changed',
            jsonb_build_object(
                'country_code', normalized_home_countries[1],
                'country_code_2', normalized_home_countries[2],
                'country_code_3', normalized_home_countries[3],
                'country_codes', to_jsonb(normalized_home_countries),
                'country_count', array_length(normalized_home_countries, 1)
            )
        );
    end if;

    select upper(country_code)
    into added_favorite_country
    from unnest(coalesce(new.favorite_countries, array[]::text[])) as country_code
    where btrim(country_code) <> ''
      and not (
          upper(country_code) = any(
              coalesce(
                  array(
                      select upper(previous_country_code)
                      from unnest(coalesce(old.favorite_countries, array[]::text[])) as previous_country_code
                  ),
                  array[]::text[]
              )
          )
      )
    order by upper(country_code)
    limit 1;

    if old.favorite_countries is distinct from new.favorite_countries
        and added_favorite_country is not null
    then
        insert into public.activity_events (actor_user_id, event_type, metadata)
        values (
            new.id,
            'favorite_country_added',
            jsonb_build_object('country_code', added_favorite_country)
        );
    end if;

    if old.avatar_url is distinct from new.avatar_url
        and new.avatar_url is not null
        and btrim(new.avatar_url) <> ''
    then
        insert into public.activity_events (actor_user_id, event_type, metadata)
        values (new.id, 'profile_photo_updated', '{}'::jsonb);
    end if;

    return new;
end;
$$;
