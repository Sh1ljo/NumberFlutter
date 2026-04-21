alter table public.profiles
  add column if not exists country text,
  add column if not exists city text;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

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
