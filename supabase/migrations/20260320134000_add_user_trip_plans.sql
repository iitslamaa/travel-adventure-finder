create table if not exists public.user_trip_plans (
    user_id uuid not null references auth.users(id) on delete cascade,
    trip_id uuid not null,
    trip_data jsonb not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (user_id, trip_id)
);

create index if not exists user_trip_plans_user_id_created_at_idx
    on public.user_trip_plans (user_id, created_at desc);

drop trigger if exists user_trip_plans_touch_updated_at on public.user_trip_plans;
create trigger user_trip_plans_touch_updated_at
before update on public.user_trip_plans
for each row
execute function touch_language_profile_updated_at();

alter table public.user_trip_plans enable row level security;

drop policy if exists "user trip plans select own" on public.user_trip_plans;
create policy "user trip plans select own"
on public.user_trip_plans
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "user trip plans insert own" on public.user_trip_plans;
create policy "user trip plans insert own"
on public.user_trip_plans
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "user trip plans update own" on public.user_trip_plans;
create policy "user trip plans update own"
on public.user_trip_plans
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "user trip plans delete own" on public.user_trip_plans;
create policy "user trip plans delete own"
on public.user_trip_plans
for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.user_trip_plans to authenticated;
