alter table if exists public.user_score_preferences
add column if not exists selected_month integer;

alter table if exists public.user_score_preferences
add column if not exists exclude_visited_countries boolean;

do $$
begin
    if to_regclass('public.user_score_preferences') is not null
        and not exists (
            select 1
            from pg_constraint
            where conname = 'user_score_preferences_selected_month_check'
        )
    then
        alter table public.user_score_preferences
        add constraint user_score_preferences_selected_month_check
        check (selected_month is null or selected_month between 1 and 12);
    end if;
end $$;
