alter table public.profiles
drop constraint if exists profiles_default_currency_code_check;

alter table public.profiles
add constraint profiles_default_currency_code_check
check (
  default_currency_code is null
  or default_currency_code ~ '^[A-Z]{3}$'
);
