do $$
begin
  if to_regclass('public.country_affordability_source') is not null then
    alter table public.country_affordability_source
      add column if not exists data_quality text;
  end if;

  if to_regclass('public.country_affordability') is not null then
    alter table public.country_affordability
      add column if not exists score numeric,
      add column if not exists band text,
      add column if not exists data_quality text,
      add column if not exists methodology text;
  end if;
end $$;
