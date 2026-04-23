alter table public.activity_events
drop constraint if exists activity_events_event_type_check;

alter table public.activity_events
add constraint activity_events_event_type_check check (
    event_type in (
        'bucket_list_added',
        'country_visited',
        'next_destination_changed',
        'profile_photo_updated',
        'current_country_changed',
        'home_country_changed',
        'favorite_country_added'
    )
);

create or replace function public.record_profile_activity_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    added_favorite_country text;
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

    if old.lived_countries is distinct from new.lived_countries
        and new.lived_countries is not null
        and array_length(new.lived_countries, 1) is not null
    then
        insert into public.activity_events (actor_user_id, event_type, metadata)
        values (
            new.id,
            'home_country_changed',
            jsonb_build_object('country_code', upper(new.lived_countries[1]))
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

drop trigger if exists profiles_record_activity_event on public.profiles;
create trigger profiles_record_activity_event
after update of current_country, next_destination, lived_countries, favorite_countries, avatar_url
on public.profiles
for each row
execute function public.record_profile_activity_event();
