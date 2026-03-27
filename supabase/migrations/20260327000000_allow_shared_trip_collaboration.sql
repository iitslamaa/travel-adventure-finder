create or replace function public.trip_plan_actor_is_participant(trip_data jsonb)
returns boolean
language sql
stable
as $$
    select
        auth.uid() is not null
        and (
            trip_data ->> 'ownerId' = auth.uid()::text
            or exists (
                select 1
                from jsonb_array_elements_text(coalesce(trip_data -> 'friendIds', '[]'::jsonb)) as participant_id
                where participant_id = auth.uid()::text
            )
        );
$$;

create or replace function public.trip_plan_row_targets_participant(target_user_id uuid, trip_data jsonb)
returns boolean
language sql
stable
as $$
    select
        target_user_id::text = trip_data ->> 'ownerId'
        or exists (
            select 1
            from jsonb_array_elements_text(coalesce(trip_data -> 'friendIds', '[]'::jsonb)) as participant_id
            where participant_id = target_user_id::text
        );
$$;

drop policy if exists "user trip plans insert own" on public.user_trip_plans;
drop policy if exists "user trip plans update own" on public.user_trip_plans;
drop policy if exists "user trip plans delete own" on public.user_trip_plans;

create policy "user trip plans insert collaborators"
on public.user_trip_plans
for insert
to authenticated
with check (
    public.trip_plan_actor_is_participant(trip_data)
    and public.trip_plan_row_targets_participant(user_id, trip_data)
);

create policy "user trip plans update collaborators"
on public.user_trip_plans
for update
to authenticated
using (
    public.trip_plan_actor_is_participant(trip_data)
)
with check (
    public.trip_plan_actor_is_participant(trip_data)
    and public.trip_plan_row_targets_participant(user_id, trip_data)
);

create policy "user trip plans delete collaborators"
on public.user_trip_plans
for delete
to authenticated
using (
    public.trip_plan_actor_is_participant(trip_data)
);
