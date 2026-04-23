-- Tutorial completion flag for cross-device consistency (mirrors local SharedPreferences).
alter table public.profiles
  add column if not exists tutorial_completed boolean not null default false;
