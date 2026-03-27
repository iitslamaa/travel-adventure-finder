drop policy if exists "user trip plans insert collaborators" on public.user_trip_plans;
drop policy if exists "user trip plans update collaborators" on public.user_trip_plans;
drop policy if exists "user trip plans delete collaborators" on public.user_trip_plans;

create policy "user trip plans insert collaborators"
on public.user_trip_plans
for insert
to authenticated
with check (
    (
        auth.uid() = user_id
        and (
            trip_data ->> 'ownerId' = auth.uid()::text
            or exists (
                select 1
                from jsonb_array_elements_text(coalesce(trip_data -> 'friendIds', '[]'::jsonb)) as participant_id
                where participant_id = auth.uid()::text
            )
        )
    )
    or (
        trip_data ->> 'ownerId' = auth.uid()::text
        and public.trip_plan_row_targets_participant(user_id, trip_data)
    )
);

create policy "user trip plans update collaborators"
on public.user_trip_plans
for update
to authenticated
using (
    auth.uid() = user_id
    or trip_data ->> 'ownerId' = auth.uid()::text
)
with check (
    (
        auth.uid() = user_id
        and public.trip_plan_row_targets_participant(user_id, trip_data)
    )
    or (
        trip_data ->> 'ownerId' = auth.uid()::text
        and public.trip_plan_row_targets_participant(user_id, trip_data)
    )
);

create policy "user trip plans delete collaborators"
on public.user_trip_plans
for delete
to authenticated
using (
    auth.uid() = user_id
    or user_trip_plans.trip_data ->> 'ownerId' = auth.uid()::text
);
