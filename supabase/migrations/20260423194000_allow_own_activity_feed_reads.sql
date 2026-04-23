drop policy if exists "activity events select friends" on public.activity_events;
create policy "activity events select social circle"
on public.activity_events
for select
to authenticated
using (
    actor_user_id = auth.uid()
    or exists (
        select 1
        from public.friends f
        where (
            f.user_id = auth.uid()
            and f.friend_id = activity_events.actor_user_id
        ) or (
            f.friend_id = auth.uid()
            and f.user_id = activity_events.actor_user_id
        )
    )
);
