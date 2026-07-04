-- V3/V5 patch: same class of bug as the subscriptions grant fix — RLS
-- policies were defined for stat_events/stat_rules/player_season_scores but
-- the base table/view privilege for `authenticated` was never granted, so
-- Postgres denied access (42501) before RLS was ever evaluated. This broke
-- live match stat recording, stat point lookup, and the player leaderboard.

grant select, insert on public.stat_events to authenticated;
grant select on public.stat_rules to authenticated;
grant select on public.player_season_scores to authenticated;
