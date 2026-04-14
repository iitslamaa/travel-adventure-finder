do $$
begin
  if to_regclass('public.country_affordability_source') is not null then
    alter table public.country_affordability_source
      add column if not exists avg_daily_usd numeric,
      add column if not exists hotel_usd numeric,
      add column if not exists hostel_usd numeric,
      add column if not exists food_usd numeric,
      add column if not exists transport_usd numeric,
      add column if not exists activities_usd numeric,
      add column if not exists methodology text;
  end if;

  if to_regclass('public.country_affordability') is not null then
    alter table public.country_affordability
      add column if not exists avg_daily_usd numeric,
      add column if not exists hotel_usd numeric,
      add column if not exists hostel_usd numeric,
      add column if not exists food_usd numeric,
      add column if not exists transport_usd numeric,
      add column if not exists activities_usd numeric;
  end if;
end
$$;
