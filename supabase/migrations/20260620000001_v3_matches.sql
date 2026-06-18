-- V3: Live match & stats

alter table public.matches
  add column if not exists status text not null default 'scheduled',
  add column if not exists started_at timestamptz,
  add column if not exists finished_at timestamptz,
  add column if not exists paused_at timestamptz,
  add column if not exists period int not null default 1;

alter table public.matches
  add constraint matches_status_check
  check (status in ('scheduled', 'live', 'paused', 'finished'));

-- append-only event log for live recording
create table if not exists public.stat_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  stat_type text not null,
  minute int,
  value int not null default 1,
  recorded_at timestamptz default now()
);

create index if not exists idx_stat_events_match_id on public.stat_events (match_id);
create index if not exists idx_stat_events_player_id on public.stat_events (player_id);

alter table public.stat_events enable row level security;

drop policy if exists stat_events_insert_own_match on public.stat_events;
create policy stat_events_insert_own_match on public.stat_events
  for insert with check (
    exists (
      select 1 from public.matches m
      join public.teams t on t.id = m.team_id
      where m.id = stat_events.match_id
        and t.owner_id = auth.uid()
    )
  );

drop policy if exists stat_events_select_own_match on public.stat_events;
create policy stat_events_select_own_match on public.stat_events
  for select using (
    exists (
      select 1 from public.matches m
      join public.teams t on t.id = m.team_id
      where m.id = stat_events.match_id
        and t.owner_id = auth.uid()
    )
  );

-- reference table: point values per sport + stat_type
create table if not exists public.stat_rules (
  sport text not null,
  stat_type text not null,
  points int not null,
  primary key (sport, stat_type)
);

alter table public.stat_rules enable row level security;

drop policy if exists stat_rules_select_authenticated on public.stat_rules;
create policy stat_rules_select_authenticated on public.stat_rules
  for select using (auth.role() = 'authenticated');

insert into public.stat_rules (sport, stat_type, points) values
  ('football',   'goal',    5),
  ('football',   'assist',  3),
  ('football',   'yellow', -2),
  ('football',   'red',    -5),
  ('football',   'shot',    0),
  ('football',   'save',    2),
  ('basketball', 'point',   1),
  ('basketball', 'rebound', 1),
  ('basketball', 'assist',  2),
  ('basketball', 'foul',   -1),
  ('volleyball', 'serve',   1),
  ('volleyball', 'block',   2),
  ('volleyball', 'error',  -1)
on conflict (sport, stat_type) do nothing;

-- aggregates stat_events → match_player_stats (football columns only)
create or replace function public.rebuild_match_player_stats(p_match_id uuid)
returns void language plpgsql security definer as $$
begin
  if not exists (
    select 1 from public.matches m
    join public.teams t on t.id = m.team_id
    where m.id = p_match_id
      and t.owner_id = auth.uid()
  ) then
    raise exception 'Not authorized';
  end if;

  delete from public.match_player_stats where match_id = p_match_id;

  insert into public.match_player_stats
    (match_id, player_id, minutes, goals, assists, yellow, red, shots, saves)
  select
    p_match_id,
    se.player_id,
    0,
    coalesce(sum(case when se.stat_type = 'goal'   then se.value else 0 end), 0),
    coalesce(sum(case when se.stat_type = 'assist' then se.value else 0 end), 0),
    least(coalesce(sum(case when se.stat_type = 'yellow' then se.value else 0 end), 0), 2),
    least(coalesce(sum(case when se.stat_type = 'red'    then se.value else 0 end), 0), 1),
    coalesce(sum(case when se.stat_type = 'shot'   then se.value else 0 end), 0),
    coalesce(sum(case when se.stat_type = 'save'   then se.value else 0 end), 0)
  from public.stat_events se
  where se.match_id = p_match_id
  group by se.player_id;
end;
$$;
