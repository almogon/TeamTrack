-- V6: League system
-- leagues can be requested by any authenticated user but stay 'pending' until
-- an admin/manager approves them; a team can join at most one active league
-- (enforced by the unique constraint on league_teams.team_id).

create table if not exists public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  city text not null check (char_length(trim(city)) > 0),
  zip_code text not null check (char_length(trim(zip_code)) > 0),
  season text not null,
  status text not null default 'pending' check (status in ('pending', 'active', 'finished')),
  -- nullable: system-generated rows from rollover_leagues() have no human creator
  created_by uuid references auth.users(id),
  validated_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_leagues_city_zip on public.leagues (city, zip_code);
create index if not exists idx_leagues_status on public.leagues (status);

alter table public.leagues enable row level security;

drop policy if exists leagues_insert_own on public.leagues;
create policy leagues_insert_own on public.leagues
  for insert with check (created_by = auth.uid());

-- Anyone can discover active leagues; the requester can see their own
-- pending/finished ones; admin/manager can see everything (validation queue).
drop policy if exists leagues_select on public.leagues;
create policy leagues_select on public.leagues
  for select using (
    status = 'active'
    or created_by = auth.uid()
    or public.is_admin_or_manager()
  );

drop policy if exists leagues_update_admin on public.leagues;
create policy leagues_update_admin on public.leagues
  for update using (public.is_admin_or_manager())
  with check (public.is_admin_or_manager());

-- No 'rejected' status in this version — rejecting a pending league is a
-- delete. Also lets a requester cancel their own still-pending request.
drop policy if exists leagues_delete on public.leagues;
create policy leagues_delete on public.leagues
  for delete using (public.is_admin_or_manager() or created_by = auth.uid());

grant select, insert, update, delete on public.leagues to authenticated;

-- ── Team membership ─────────────────────────────────────────────────────────

create table if not exists public.league_teams (
  league_id uuid not null references public.leagues(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, team_id),
  unique (team_id) -- one league per team
);

alter table public.league_teams enable row level security;

-- Membership rows aren't sensitive on their own (just team<->league links)
-- and need to be readable by any team's owner to render standings/discovery.
drop policy if exists league_teams_select on public.league_teams;
create policy league_teams_select on public.league_teams
  for select using (true);

drop policy if exists league_teams_insert_owner on public.league_teams;
create policy league_teams_insert_owner on public.league_teams
  for insert with check (
    exists (
      select 1 from public.teams t
      where t.id = league_teams.team_id and t.owner_id = auth.uid()
    )
    and exists (
      select 1 from public.leagues l
      where l.id = league_teams.league_id and l.status = 'active'
    )
  );

-- Once a team joins a league it cannot leave — only admin/manager can
-- remove a team from a league (e.g. administrative cleanup).
drop policy if exists league_teams_delete on public.league_teams;
create policy league_teams_delete on public.league_teams
  for delete using (public.is_admin_or_manager());

grant select, insert, delete on public.league_teams to authenticated;

-- ── Canonical registry for season auto-renewal ─────────────────────────────
-- Not exposed in the app UI in this version — admins manage it directly.

create table if not exists public.default_leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) > 0),
  city text not null check (char_length(trim(city)) > 0),
  zip_code text not null check (char_length(trim(zip_code)) > 0)
);

alter table public.default_leagues enable row level security;

drop policy if exists default_leagues_admin on public.default_leagues;
create policy default_leagues_admin on public.default_leagues
  for all using (public.is_admin_or_manager()) with check (public.is_admin_or_manager());

grant select, insert, update, delete on public.default_leagues to authenticated;

-- ── Season rollover ─────────────────────────────────────────────────────────
-- League seasons run a fixed 1 July -> 30 June calendar.

create or replace function public.current_league_season()
returns text
language sql
stable
as $$
  select case
    when extract(month from now()) >= 7
      then extract(year from now())::text || '-' || (extract(year from now())::int + 1)::text
    else (extract(year from now())::int - 1)::text || '-' || extract(year from now())::text
  end;
$$;

grant execute on function public.current_league_season() to authenticated;

-- Inserts the next season's edition of every default league. Intended to be
-- invoked at season end via the SQL editor, a scheduled Edge Function, or
-- pg_cron — not exposed to the app (no grant to `authenticated`).
create or replace function public.rollover_leagues()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  next_season text := public.current_league_season();
begin
  insert into public.leagues (name, city, zip_code, season, status, created_by)
  select dl.name, dl.city, dl.zip_code, next_season, 'active', null
  from public.default_leagues dl
  where not exists (
    select 1 from public.leagues l
    where l.city = dl.city and l.zip_code = dl.zip_code
      and l.name = dl.name and l.season = next_season
  );
end;
$$;

-- ── Standings ────────────────────────────────────────────────────────────
-- SECURITY DEFINER function (not a plain view): standings need to aggregate
-- match results across every team in the league, but `matches` RLS is
-- owner-only, so a caller who doesn't own a given match row can't see it
-- directly. This bypasses that for aggregated win/draw/loss/points only —
-- no raw match rows are exposed, just the computed table.
-- Each team's matches are counted from that team's own logged rows (there is
-- no cross-team match dedup in this schema), matching how the rest of the
-- app already trusts each team's own recorded data (see player_season_scores).
create or replace function public.league_standings(p_league_id uuid)
returns table (
  team_id uuid,
  team_name text,
  wins int,
  draws int,
  losses int,
  goals_for int,
  goals_against int,
  points int
)
language sql
security definer
set search_path = public
as $$
  with league_matches as (
    select
      lt.team_id,
      case when m.local_team_id = m.team_id then m.score_for else m.score_against end as gf,
      case when m.local_team_id = m.team_id then m.score_against else m.score_for end as ga
    from public.matches m
    join public.league_teams lt on lt.team_id = m.team_id and lt.league_id = p_league_id
    join public.league_teams opp on opp.league_id = lt.league_id
      and opp.team_id = (case when m.local_team_id = m.team_id then m.visitant_team_id else m.local_team_id end)
    where m.status = 'finished'
      and m.score_for is not null
      and m.score_against is not null
  )
  select
    t.id,
    t.name,
    count(lm.team_id) filter (where lm.gf > lm.ga)::int,
    count(lm.team_id) filter (where lm.gf = lm.ga)::int,
    count(lm.team_id) filter (where lm.gf < lm.ga)::int,
    coalesce(sum(lm.gf), 0)::int,
    coalesce(sum(lm.ga), 0)::int,
    (count(lm.team_id) filter (where lm.gf > lm.ga) * 3
      + count(lm.team_id) filter (where lm.gf = lm.ga))::int
  from public.league_teams lt
  join public.teams t on t.id = lt.team_id
  left join league_matches lm on lm.team_id = lt.team_id
  where lt.league_id = p_league_id
  group by t.id, t.name
  order by 8 desc, 6 desc;
$$;

grant execute on function public.league_standings(uuid) to authenticated;
