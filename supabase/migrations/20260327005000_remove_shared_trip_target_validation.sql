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

    if not (auth.uid() = any(target_user_ids)) then
        raise exception 'Current user is not included in target participants';
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
begin
    if auth.uid() is null then
        raise exception 'Not authenticated';
    end if;

    if not (auth.uid() = any(target_user_ids)) then
        raise exception 'Current user is not included in target participants';
    end if;

    delete from public.user_trip_plans
    where user_trip_plans.trip_id = delete_shared_trip_plan.trip_id
      and user_trip_plans.user_id = any(delete_shared_trip_plan.target_user_ids);
end;
$$;
