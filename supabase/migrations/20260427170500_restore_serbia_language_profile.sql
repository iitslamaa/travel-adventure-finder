insert into place_language_profile_overrides (
  place_type,
  place_code,
  languages,
  notes,
  override_reason,
  evidence
)
values (
  'country',
  'RS',
  '[{"code":"sr","type":"official","coverage":1},{"code":"en","type":"widely_spoken","coverage":0.65}]'::jsonb,
  'Serbia should score Serbian as the primary local language while giving strong English credit in travel contexts because official tourism infrastructure serves visitors in English.',
  'official_serbian_with_tourism_english_override',
  '[{"kind":"reference","title":"Britannica: Serbia","url":"https://www.britannica.com/place/Serbia","note":"Britannica identifies Serbian as the principal language of Serbia."},{"kind":"official_tourism","title":"National Tourism Organisation of Serbia","url":"https://www.serbia.travel/en/contact/","note":"Serbia''s official tourism organization maintains an English-facing visitor site, supporting strong tourism usability in English."}]'::jsonb
)
on conflict (place_type, place_code) do update
set
  languages = excluded.languages,
  notes = excluded.notes,
  override_reason = excluded.override_reason,
  evidence = excluded.evidence,
  updated_at = now();
