-- ================================
-- VISA REQUIREMENTS (VERSIONED)
-- ================================

create table if not exists visa_requirements (
    id uuid primary key default gen_random_uuid(),

    visitor_to_raw text not null,
    visitor_to_norm text not null,

    parent_norm text,
    is_special_subregion boolean default false,

    requirement text,
    allowed_stay text,
    notes text,

    version integer not null,
    source text not null default 'wikipedia',

    last_verified_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index if not exists visa_requirements_visitor_norm_idx
on visa_requirements (visitor_to_norm);

create index if not exists visa_requirements_version_idx
on visa_requirements (version);


-- ================================
-- VISA SYNC RUNS (AUDIT LOG)
-- ================================

create table if not exists visa_sync_runs (
    id uuid primary key default gen_random_uuid(),

    version integer not null,
    started_at timestamptz not null default now(),
    completed_at timestamptz,
    row_count integer,
    notes text
);


-- ================================
-- VISA CHANGE LOG (DIFF TRACKING)
-- ================================

create table if not exists visa_requirement_changes (
    id uuid primary key default gen_random_uuid(),

    visitor_to_norm text not null,

    old_requirement text,
    new_requirement text,

    old_allowed_stay text,
    new_allowed_stay text,

    changed_at timestamptz not null default now(),
    version integer not null
);