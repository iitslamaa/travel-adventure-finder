drop function if exists public.share_trip_plan(uuid[], uuid, jsonb);
drop function if exists public.delete_shared_trip_plan(uuid[], uuid, jsonb);

create or replace function public.share_trip_plan(
    target_user_ids uuid[],
    trip_id uuid,
    trip_payload text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    parsed_trip_data jsonb := trip_payload::jsonb;
begin
    if auth.uid() is null then
        raise exception 'Not authenticated';
    end if;

    if not public.trip_plan_actor_is_participant(parsed_trip_data) then
        raise exception 'Current user is not a participant on this trip';
    end if;

    if exists (
        select 1
        from unnest(target_user_ids) as target_user_id
        where not public.trip_plan_row_targets_participant(target_user_id, parsed_trip_data)
    ) then
        raise exception 'Target user list contains a non-participant';
    end if;

    delete from public.user_trip_plans
    where user_trip_plans.trip_id = share_trip_plan.trip_id
      and not (user_trip_plans.user_id = any(share_trip_plan.target_user_ids));

    insert into public.user_trip_plans (user_id, trip_id, trip_data)
    select target_user_id, share_trip_plan.trip_id, parsed_trip_data
    from unnest(target_user_ids) as target_user_id
    on conflict (user_id, trip_id) do update
    set trip_data = excluded.trip_data,
        updated_at = now();
end;
$$;

create or replace function public.delete_shared_trip_plan(
    target_user_ids uuid[],
    trip_id uuid,
    trip_payload text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    parsed_trip_data jsonb := trip_payload::jsonb;
begin
    if auth.uid() is null then
        raise exception 'Not authenticated';
    end if;

    if not public.trip_plan_actor_is_participant(parsed_trip_data) then
        raise exception 'Current user is not a participant on this trip';
    end if;

    delete from public.user_trip_plans
    where user_trip_plans.trip_id = delete_shared_trip_plan.trip_id
      and user_trip_plans.user_id = any(delete_shared_trip_plan.target_user_ids);
end;
$$;

grant execute on function public.share_trip_plan(uuid[], uuid, text) to authenticated;
grant execute on function public.delete_shared_trip_plan(uuid[], uuid, text) to authenticated;
