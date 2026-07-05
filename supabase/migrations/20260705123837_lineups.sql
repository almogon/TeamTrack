-- Line-up management: which formation a team has chosen, and which player
-- (if any) occupies each slot of that formation. The set of available
-- formations (shapes/slot counts) is a hardcoded list in the Flutter app,
-- not stored here — only the team's current selection and assignments are.

alter table public.teams
  add column if not exists lineup_formation text;

create table if not exists public.lineup_slots (
  team_id uuid not null references public.teams(id) on delete cascade,
  slot_index int not null,
  player_id uuid references public.players(id) on delete set null,
  primary key (team_id, slot_index)
);

alter table public.lineup_slots enable row level security;

-- Mirrors the current owner-only policy on teams/players (V1 team_members
-- membership model isn't implemented yet, so there's no wider "member" role).
drop policy if exists lineup_slots_select_own_team on public.lineup_slots;
create policy lineup_slots_select_own_team on public.lineup_slots
  for select using (
    exists (
      select 1 from public.teams t
      where t.id = lineup_slots.team_id and t.owner_id = auth.uid()
    )
  );

drop policy if exists lineup_slots_insert_own_team on public.lineup_slots;
create policy lineup_slots_insert_own_team on public.lineup_slots
  for insert with check (
    exists (
      select 1 from public.teams t
      where t.id = lineup_slots.team_id and t.owner_id = auth.uid()
    )
  );

drop policy if exists lineup_slots_update_own_team on public.lineup_slots;
create policy lineup_slots_update_own_team on public.lineup_slots
  for update using (
    exists (
      select 1 from public.teams t
      where t.id = lineup_slots.team_id and t.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.teams t
      where t.id = lineup_slots.team_id and t.owner_id = auth.uid()
    )
  );

drop policy if exists lineup_slots_delete_own_team on public.lineup_slots;
create policy lineup_slots_delete_own_team on public.lineup_slots
  for delete using (
    exists (
      select 1 from public.teams t
      where t.id = lineup_slots.team_id and t.owner_id = auth.uid()
    )
  );

grant select, insert, update, delete on public.lineup_slots to authenticated;
