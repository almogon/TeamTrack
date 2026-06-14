-- Refactor matches: replace opponent+home_away with explicit local/visitant teams.
-- team_id is kept as the "managing" team for RLS purposes.
-- Each side can be an app team (via id FK) or an external team (via name text).

alter table public.matches
  drop column if exists opponent,
  drop column if exists home_away,
  add column if not exists local_team_id    uuid references public.teams(id) on delete set null,
  add column if not exists local_team_name  text,
  add column if not exists visitant_team_id uuid references public.teams(id) on delete set null,
  add column if not exists visitant_team_name text;

-- at least one of id/name must be set for each side
alter table public.matches
  add constraint matches_local_team_check check (
    local_team_id is not null
    or (local_team_name is not null and char_length(trim(local_team_name)) > 0)
  ),
  add constraint matches_visitant_team_check check (
    visitant_team_id is not null
    or (visitant_team_name is not null and char_length(trim(visitant_team_name)) > 0)
  );
