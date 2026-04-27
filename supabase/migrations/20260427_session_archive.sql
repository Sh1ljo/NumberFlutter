-- Session archive for tracking historical session data and statistics
create table if not exists public.session_archive (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_number integer not null,
  number_numeric text not null default '0',
  click_power_numeric text not null default '50',
  auto_click_rate double precision not null default 0,
  prestige_currency double precision not null default 0,
  prestige_multiplier double precision not null default 1,
  prestige_count integer not null default 0,
  permanent_click_purchases integer not null default 0,
  permanent_idle_purchases integer not null default 0,
  upgrade_levels jsonb not null default '{}'::jsonb,
  nexus_levels jsonb not null default '{}'::jsonb,
  highest_number_numeric text not null default '0',
  progress_score bigint not null default 0,
  archived_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Add aggregate stats columns to profiles table
alter table public.profiles
  add column if not exists total_sessions integer not null default 0,
  add column if not exists average_highest_number_numeric text,
  add column if not exists average_prestige_currency double precision default 0,
  add column if not exists total_prestige_currency double precision default 0,
  add column if not exists max_highest_number_numeric text,
  add column if not exists last_session_archived_at timestamptz;

-- Create indexes for better performance
create index if not exists idx_session_archive_user_id on public.session_archive(user_id);
create index if not exists idx_session_archive_archived_at on public.session_archive(archived_at);
create index if not exists idx_session_archive_user_session on public.session_archive(user_id, session_number);

-- Enable RLS on session_archive
alter table public.session_archive enable row level security;

-- RLS policies for session_archive
drop policy if exists "session_archive_select_own" on public.session_archive;
create policy "session_archive_select_own"
on public.session_archive
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "session_archive_insert_own" on public.session_archive;
create policy "session_archive_insert_own"
on public.session_archive
for insert
to authenticated
with check (auth.uid() = user_id);

-- Function to update profile stats when a session is archived
create or replace function public.update_profile_session_stats()
returns trigger
language plpgsql
as $$
declare
  _total_sessions integer;
  _avg_prestige_currency double precision;
  _total_prestige_currency double precision;
  _max_highest_number_numeric text;
begin
  -- Calculate aggregate stats from session_archive
  select
    count(*)::integer,
    coalesce(avg(prestige_currency), 0),
    coalesce(sum(prestige_currency), 0),
    coalesce(max(highest_number_numeric order by (highest_number_numeric::numeric) desc), '0')
  into
    _total_sessions,
    _avg_prestige_currency,
    _total_prestige_currency,
    _max_highest_number_numeric
  from public.session_archive
  where user_id = new.user_id;

  -- Update profiles table with the aggregated stats
  update public.profiles
  set
    total_sessions = _total_sessions,
    average_prestige_currency = _avg_prestige_currency,
    total_prestige_currency = _total_prestige_currency,
    max_highest_number_numeric = _max_highest_number_numeric,
    last_session_archived_at = new.archived_at
  where id = new.user_id;

  return new;
end;
$$;

-- Drop existing trigger if it exists
drop trigger if exists session_archive_update_profile_stats on public.session_archive;

-- Create trigger to update profile stats when session is archived
create trigger session_archive_update_profile_stats
after insert on public.session_archive
for each row
execute function public.update_profile_session_stats();
