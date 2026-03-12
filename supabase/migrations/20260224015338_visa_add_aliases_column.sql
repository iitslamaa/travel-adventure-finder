alter table visa_requirements
add column if not exists aliases_norm text[];

alter table visa_requirements
add column if not exists parent_norm text;

alter table visa_requirements
add column if not exists is_special_subregion boolean default false;