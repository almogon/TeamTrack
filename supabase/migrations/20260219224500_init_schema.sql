create extension if not exists pgcrypto;

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  season text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  position text,
  number int check (number is null or number >= 0),
  birthdate date,
  active boolean not null default true,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  match_date date not null,
  opponent text not null check (char_length(trim(opponent)) > 0),
  home_away text not null check (home_away in ('home', 'away')),
  competition text,
  notes text,
  score_for int check (score_for is null or score_for >= 0),
  score_against int check (score_against is null or score_against >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_player_stats (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  minutes int not null default 0 check (minutes between 0 and 120),
  goals int not null default 0 check (goals >= 0),
  assists int not null default 0 check (assists >= 0),
  yellow int not null default 0 check (yellow between 0 and 2),
  red int not null default 0 check (red between 0 and 1),
  shots int not null default 0 check (shots >= 0),
  saves int not null default 0 check (saves >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, player_id)
);

create index if not exists idx_teams_owner_id on public.teams (owner_id);
create index if not exists idx_players_team_id on public.players (team_id);
create index if not exists idx_matches_team_date on public.matches (team_id, match_date desc);
create index if not exists idx_stats_match_id on public.match_player_stats (match_id);
create index if not exists idx_stats_player_id on public.match_player_stats (player_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_teams_updated_at on public.teams;
create trigger trg_teams_updated_at
before update on public.teams
for each row execute function public.set_updated_at();

drop trigger if exists trg_players_updated_at on public.players;
create trigger trg_players_updated_at
before update on public.players
for each row execute function public.set_updated_at();

drop trigger if exists trg_matches_updated_at on public.matches;
create trigger trg_matches_updated_at
before update on public.matches
for each row execute function public.set_updated_at();

drop trigger if exists trg_stats_updated_at on public.match_player_stats;
create trigger trg_stats_updated_at
before update on public.match_player_stats
for each row execute function public.set_updated_at();

alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_player_stats enable row level security;

drop policy if exists teams_select_own on public.teams;
create policy teams_select_own
on public.teams for select
using (owner_id = auth.uid());

drop policy if exists teams_insert_own on public.teams;
create policy teams_insert_own
on public.teams for insert
with check (owner_id = auth.uid());

drop policy if exists teams_update_own on public.teams;
create policy teams_update_own
on public.teams for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists teams_delete_own on public.teams;
create policy teams_delete_own
on public.teams for delete
using (owner_id = auth.uid());

drop policy if exists players_select_own_team on public.players;
create policy players_select_own_team
on public.players for select
using (
  exists (
    select 1
    from public.teams t
    where t.id = players.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists players_insert_own_team on public.players;
create policy players_insert_own_team
on public.players for insert
with check (
  exists (
    select 1
    from public.teams t
    where t.id = players.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists players_update_own_team on public.players;
create policy players_update_own_team
on public.players for update
using (
  exists (
    select 1
    from public.teams t
    where t.id = players.team_id
      and t.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.teams t
    where t.id = players.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists players_delete_own_team on public.players;
create policy players_delete_own_team
on public.players for delete
using (
  exists (
    select 1
    from public.teams t
    where t.id = players.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists matches_select_own_team on public.matches;
create policy matches_select_own_team
on public.matches for select
using (
  exists (
    select 1
    from public.teams t
    where t.id = matches.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists matches_insert_own_team on public.matches;
create policy matches_insert_own_team
on public.matches for insert
with check (
  exists (
    select 1
    from public.teams t
    where t.id = matches.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists matches_update_own_team on public.matches;
create policy matches_update_own_team
on public.matches for update
using (
  exists (
    select 1
    from public.teams t
    where t.id = matches.team_id
      and t.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.teams t
    where t.id = matches.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists matches_delete_own_team on public.matches;
create policy matches_delete_own_team
on public.matches for delete
using (
  exists (
    select 1
    from public.teams t
    where t.id = matches.team_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists stats_select_own_match on public.match_player_stats;
create policy stats_select_own_match
on public.match_player_stats for select
using (
  exists (
    select 1
    from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_player_stats.match_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists stats_insert_own_match on public.match_player_stats;
create policy stats_insert_own_match
on public.match_player_stats for insert
with check (
  exists (
    select 1
    from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_player_stats.match_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists stats_update_own_match on public.match_player_stats;
create policy stats_update_own_match
on public.match_player_stats for update
using (
  exists (
    select 1
    from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_player_stats.match_id
      and t.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_player_stats.match_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists stats_delete_own_match on public.match_player_stats;
create policy stats_delete_own_match
on public.match_player_stats for delete
using (
  exists (
    select 1
    from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_player_stats.match_id
      and t.owner_id = auth.uid()
  )
);