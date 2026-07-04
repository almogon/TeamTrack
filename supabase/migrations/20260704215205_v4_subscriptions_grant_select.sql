-- V4 patch: the subscriptions table's RLS policy alone isn't enough — Postgres
-- denies access before RLS is even evaluated if the base table privilege is
-- missing. subscriptionProvider (app-side read of the caller's own row) was
-- failing with "permission denied for table subscriptions" (42501) because
-- this grant was never added when the table was created.

grant select on public.subscriptions to authenticated;
