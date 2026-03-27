drop function if exists public.share_trip_plan(uuid[], uuid, text);
drop function if exists public.delete_shared_trip_plan(uuid[], uuid, text);

create or replace function public.share_trip_plan(
    p_target_user_ids uuid[],
    p_trip_id uuid,
    p_trip_payload text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    parsed_trip_data jsonb := p_trip_payload::jsonb;
begin
    if auth.uid() is null then
        raise exception 'Not authenticated';
    end if;

    if not (auth.uid() = any(p_target_user_ids)) then
        raise exception 'Current user is not included in target participants';
    end if;

    delete from public.user_trip_plans
    where public.user_trip_plans.trip_id = p_trip_id
      and not (public.user_trip_plans.user_id = any(p_target_user_ids));

    insert into public.user_trip_plans (user_id, trip_id, trip_data)
    select target_user_id, p_trip_id, parsed_trip_data
    from unnest(p_target_user_ids) as target_user_id
    on conflict (user_id, trip_id) do update
    set trip_data = excluded.trip_data,
        updated_at = now();
end;
$$;

create or replace function public.delete_shared_trip_plan(
    p_target_user_ids uuid[],
    p_trip_id uuid,
    p_trip_payload text
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

    if not (auth.uid() = any(p_target_user_ids)) then
        raise exception 'Current user is not included in target participants';
    end if;

    delete from public.user_trip_plans
    where public.user_trip_plans.trip_id = p_trip_id
      and public.user_trip_plans.user_id = any(p_target_user_ids);
end;
$$;

grant execute on function public.share_trip_plan(uuid[], uuid, text) to authenticated;
grant execute on function public.delete_shared_trip_plan(uuid[], uuid, text) to authenticated;
