alter table public.profiles
add column if not exists default_currency_code text;

update public.profiles
set default_currency_code = coalesce(nullif(upper(trim(default_currency_code)), ''), 'USD')
where default_currency_code is null
   or trim(default_currency_code) = '';

alter table public.profiles
alter column default_currency_code set default 'USD';

alter table public.profiles
drop constraint if exists profiles_default_currency_code_check;

alter table public.profiles
add constraint profiles_default_currency_code_check
check (
    default_currency_code is null
    or default_currency_code in (
        'USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'HKD', 'INR',
        'MXN', 'NZD', 'SGD', 'THB', 'TRY', 'ZAR', 'BRL', 'DKK', 'NOK', 'SEK',
        'PLN', 'CZK', 'HUF', 'RON', 'ILS', 'IDR', 'KRW', 'MYR', 'PHP'
    )
);
