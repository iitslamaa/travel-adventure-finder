alter table if exists public.user_score_preferences
add column if not exists language double precision;
