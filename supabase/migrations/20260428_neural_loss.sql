-- Neural Network loss progression columns + leaderboard support.
--
-- Adds two doubles to player_progress:
--   neural_loss        — current training loss (0..1], decays over time
--   neural_lowest_loss — best (lowest) loss this user ever reached;
--                        the leaderboard "loss" metric ranks ascending by this.
--
-- Existing rows backfill to 1.0 (untrained network), so they appear at the
-- bottom of the loss leaderboard until they sync a real value.

alter table public.player_progress
  add column if not exists neural_loss double precision not null default 1.0,
  add column if not exists neural_lowest_loss double precision not null default 1.0;

-- Index for the loss leaderboard's ASC sort.
create index if not exists idx_player_progress_neural_lowest_loss
  on public.player_progress (neural_lowest_loss asc);

-- Replace the leaderboard view to expose neural_lowest_loss alongside the
-- existing number column. The fallback path in SupabaseService.fetchLeaderboard
-- queries this view directly when the RPC isn't deployed.
drop view if exists public.leaderboard_view;

create view public.leaderboard_view as
select
  dense_rank() over (
    order by
      char_length(pp.highest_number_numeric) desc,
      pp.highest_number_numeric desc
  ) as rank,
  dense_rank() over (
    order by pp.neural_lowest_loss asc
  ) as loss_rank,
  pp.user_id,
  coalesce(nullif(p.display_name, ''), 'Player') as display_name,
  nullif(p.country, '') as country,
  nullif(p.city, '') as city,
  pp.highest_number_numeric,
  pp.neural_lowest_loss,
  pp.updated_at
from public.player_progress pp
left join public.profiles p on p.id = pp.user_id;

-- Extend the leaderboard RPC with a `metric` parameter:
--   'number' (default) — sorts DESC by highest_number_numeric (existing behavior)
--   'loss'             — sorts ASC by neural_lowest_loss
--
-- Both metrics return the same row shape so the client can render either.
create or replace function public.get_leaderboard(
  scope_country text default null,
  scope_city text default null,
  row_limit integer default 100,
  metric text default 'number'
)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  country text,
  city text,
  highest_number_numeric text,
  neural_lowest_loss double precision,
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
      pp.neural_lowest_loss,
      pp.updated_at
    from public.player_progress pp
    left join public.profiles p on p.id = pp.user_id
    where
      (scope_country is null or p.country = scope_country)
      and (scope_city is null or p.city = scope_city)
  ),
  ranked as (
    select
      case
        when metric = 'loss' then
          dense_rank() over (order by scoped.neural_lowest_loss asc)
        else
          dense_rank() over (
            order by
              char_length(scoped.highest_number_numeric) desc,
              scoped.highest_number_numeric desc
          )
      end as rank,
      scoped.*
    from scoped
  )
  select
    ranked.rank,
    ranked.user_id,
    ranked.display_name,
    ranked.country,
    ranked.city,
    ranked.highest_number_numeric,
    ranked.neural_lowest_loss,
    ranked.updated_at
  from ranked
  order by ranked.rank asc
  limit greatest(row_limit, 1);
$$;
