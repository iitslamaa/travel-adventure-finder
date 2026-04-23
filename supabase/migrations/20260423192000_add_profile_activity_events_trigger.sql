create or replace function public.record_profile_activity_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
after update of current_country, next_destination, lived_countries, avatar_url
on public.profiles
for each row
execute function public.record_profile_activity_event();
