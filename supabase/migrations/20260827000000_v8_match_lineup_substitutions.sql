-- V8: per-match lineup + substitution tracking
--
-- Lets a trainer set a match's starting XI (mirroring the team's persistent
-- Line-Up, but independently mutable — substitutions during a match must
-- never change the team's own saved lineup) and records who's on/off the
-- pitch and when, so total playing time per match can be computed for
-- analytics.

alter table public.matches
  add column if not exists lineup_formation text;

-- Mirrors public.lineup_slots exactly, just keyed by match instead of team.
create table if not exists public.match_lineup_slots (
  match_id   uuid not null references public.matches (id) on delete cascade,
  slot_index int  not null,
  player_id  uuid references public.players (id) on delete set null,
  primary key (match_id, slot_index)
);

-- One row per stint a player spends on the pitch during a match. A starting
-- player gets minute_in = 0 when the match is started; a substitute gets
-- minute_in = the clock at the moment they come on. minute_out is filled in
-- when they're subbed off, or by endMatch() for anyone still on the pitch
-- when the match finishes. Total minutes played = sum(minute_out - minute_in)
-- across a player's rows for that match.
create table if not exists public.match_substitutions (
  id         uuid primary key default gen_random_uuid(),
  match_id   uuid not null references public.matches (id) on delete cascade,
  player_id  uuid not null references public.players (id) on delete cascade,
  minute_in  int not null default 0,
  minute_out int,
  created_at timestamptz not null default now()
);

create index if not exists idx_match_lineup_slots_match on public.match_lineup_slots (match_id);
create index if not exists idx_match_subs_match on public.match_substitutions (match_id);
create index if not exists idx_match_subs_open on public.match_substitutions (match_id, player_id) where minute_out is null;

alter table public.match_lineup_slots enable row level security;
alter table public.match_substitutions enable row level security;

-- Same owner-via-match-via-team scoping as stat_events.
drop policy if exists match_lineup_slots_owner on public.match_lineup_slots;
create policy match_lineup_slots_owner
on public.match_lineup_slots for all
using (
  exists (
    select 1 from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_lineup_slots.match_id
      and t.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_lineup_slots.match_id
      and t.owner_id = auth.uid()
  )
);

drop policy if exists match_substitutions_owner on public.match_substitutions;
create policy match_substitutions_owner
on public.match_substitutions for all
using (
  exists (
    select 1 from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_substitutions.match_id
      and t.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = match_substitutions.match_id
      and t.owner_id = auth.uid()
  )
);

grant select, insert, update, delete on public.match_lineup_slots to authenticated;
grant select, insert, update, delete on public.match_substitutions to authenticated;
