create table if not exists public.activity_events (
    id uuid primary key default gen_random_uuid(),
    actor_user_id uuid not null references public.profiles(id) on delete cascade,
    event_type text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    constraint activity_events_event_type_check check (
        event_type in (
            'bucket_list_added',
            'country_visited',
            'next_destination_changed',
            'profile_photo_updated',
            'current_country_changed',
            'home_country_changed'
        )
    ),
    constraint activity_events_metadata_object_check check (jsonb_typeof(metadata) = 'object')
);

create index if not exists activity_events_actor_created_idx
on public.activity_events (actor_user_id, created_at desc);

create index if not exists activity_events_created_idx
on public.activity_events (created_at desc);

alter table public.activity_events enable row level security;

drop policy if exists "activity events select friends" on public.activity_events;
create policy "activity events select friends"
on public.activity_events
for select
to authenticated
using (
    exists (
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

drop policy if exists "activity events insert own" on public.activity_events;
create policy "activity events insert own"
on public.activity_events
for insert
to authenticated
with check (actor_user_id = auth.uid());
