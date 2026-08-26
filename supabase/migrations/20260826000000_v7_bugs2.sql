-- V7: bugs-2 batch
-- 1. Soft-delete ("archive") for teams, mirroring players.active.
-- 2. player_season_scores keeps a removed player's row when they still
--    have finished-match stats, instead of dropping them outright — a
--    trainer who archives a player shouldn't lose that player's historical
--    points from the leaderboard or match summaries.

alter table public.teams
  add column if not exists archived boolean not null default false;

CREATE OR REPLACE VIEW player_season_scores AS
WITH finished_events AS (
  SELECT
    se.player_id,
    se.match_id,
    se.stat_type,
    se.value
  FROM stat_events se
  JOIN matches m ON m.id = se.match_id
  WHERE m.status = 'finished'
)
SELECT
  p.id                                                          AS player_id,
  p.team_id,
  p.name                                                        AS player_name,
  p.alias                                                       AS player_alias,
  p.number                                                      AS player_number,
  p.position                                                    AS player_position,
  t.season,
  t.sport,
  COALESCE(SUM(sr.points * fe.value), 0)::int                  AS total_points,
  COUNT(DISTINCT fe.match_id)::int                              AS matches_played
FROM players p
JOIN teams t ON t.id = p.team_id
LEFT JOIN finished_events fe ON fe.player_id = p.id
LEFT JOIN stat_rules sr
  ON  sr.sport     = t.sport
  AND sr.stat_type = fe.stat_type
WHERE p.active = TRUE
   OR EXISTS (SELECT 1 FROM finished_events fe2 WHERE fe2.player_id = p.id)
GROUP BY
  p.id, p.team_id, p.name, p.alias, p.number, p.position,
  t.season, t.sport;
