alter table if exists public.profiles
    add column if not exists first_name text,
    add column if not exists last_name text;

update public.profiles
set
    first_name = coalesce(
        nullif(first_name, ''),
        nullif(split_part(trim(coalesce(full_name, '')), ' ', 1), '')
    ),
    last_name = coalesce(
        nullif(last_name, ''),
        nullif(
            trim(
                substring(
                    trim(coalesce(full_name, ''))
                    from char_length(split_part(trim(coalesce(full_name, '')), ' ', 1)) + 1
                )
            ),
            ''
        )
    )
where coalesce(nullif(trim(coalesce(full_name, '')), ''), '') <> '';
