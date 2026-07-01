-- V5: Player scoring & history
-- Creates a view that aggregates stat_events into per-player season scores.
-- The view is readable by any authenticated user who owns the underlying team
-- (RLS on players + teams + stat_events applies automatically via SECURITY INVOKER).

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
GROUP BY
  p.id, p.team_id, p.name, p.alias, p.number, p.position,
  t.season, t.sport;
