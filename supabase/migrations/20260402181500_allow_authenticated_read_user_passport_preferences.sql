drop policy if exists "user passport preferences select own" on public.user_passport_preferences;

create policy "user passport preferences select authenticated"
on public.user_passport_preferences
for select
to authenticated
using (true);
