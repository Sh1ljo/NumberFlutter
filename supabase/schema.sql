-- Run this in Supabase SQL Editor for NumberFlutter.
-- This schema stores player progression, account profile, and leaderboard data.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  country text,
  city text,
  tutorial_completed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.player_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  number_numeric text not null default '0',
  click_power_numeric text not null default '50',
  auto_click_rate double precision not null default 0,
  prestige_currency double precision not null default 0,
  prestige_multiplier double precision not null default 1,
  prestige_count integer not null default 0,
  permanent_click_purchases integer not null default 0,
  permanent_idle_purchases integer not null default 0,
  upgrade_levels jsonb not null default '{}'::jsonb,
  highest_number_numeric text not null default '0',
  progress_score bigint not null default 0,
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists player_progress_set_updated_at on public.player_progress;
create trigger player_progress_set_updated_at
before update on public.player_progress
for each row
execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.player_progress enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "progress_select_authenticated" on public.player_progress;
create policy "progress_select_authenticated"
on public.player_progress
for select
to authenticated
using (true);

drop policy if exists "progress_insert_own" on public.player_progress;
create policy "progress_insert_own"
on public.player_progress
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "progress_update_own" on public.player_progress;
create policy "progress_update_own"
on public.player_progress
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop view if exists public.leaderboard_view;

create view public.leaderboard_view as
select
  dense_rank() over (
    order by
      char_length(pp.highest_number_numeric) desc,
      pp.highest_number_numeric desc
  ) as rank,
  pp.user_id,
  coalesce(nullif(p.display_name, ''), 'Player') as display_name,
  nullif(p.country, '') as country,
  nullif(p.city, '') as city,
  pp.highest_number_numeric,
  pp.updated_at
from public.player_progress pp
left join public.profiles p on p.id = pp.user_id;

create or replace function public.get_leaderboard(
  scope_country text default null,
  scope_city text default null,
  row_limit integer default 100
)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  country text,
  city text,
  highest_number_numeric text,
  updated_at timestamptz
)
language sql
stable
as $$
  with scoped as (
    select
      pp.user_id,
      coalesce(nullif(p.display_name, ''), 'Player') as display_name,
      nullif(p.country, '') as country,
      nullif(p.city, '') as city,
      pp.highest_number_numeric,
      pp.updated_at
    from public.player_progress pp
    left join public.profiles p on p.id = pp.user_id
    where
      (scope_country is null or p.country = scope_country)
      and (scope_city is null or p.city = scope_city)
  )
  select
    dense_rank() over (
      order by
        char_length(scoped.highest_number_numeric) desc,
        scoped.highest_number_numeric desc
    ) as rank,
    scoped.user_id,
    scoped.display_name,
    scoped.country,
    scoped.city,
    scoped.highest_number_numeric,
    scoped.updated_at
  from scoped
  order by rank asc
  limit greatest(row_limit, 1);
$$;
