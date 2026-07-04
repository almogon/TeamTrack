# TeamTrack

A Flutter mobile app for sports trainers to manage teams, players, and match statistics in real time.

## Features (implemented — V0 to V5)

- **Auth** — Register/login with email or username, password recovery ("Forgot password?" on the login screen), profile with role (`user` / `manager` / `admin`)
- **Multi-sport teams** — Football (5/7/11), Basketball (5), Volleyball (6), with sport-aware formats and player positions
- **Team management** — Create teams, add/edit players (name, alias, number, position, birthdate)
- **Live match recording** — Create a match, run it live with a client-side timer, log stat events per player, pause/resume/end, local notifications for halftime and match end
- **Match summary** — Post-match per-player stat table with calculated points
- **Player scoring & history** — Stats converted to points via `stat_rules` (goal: 5, assist: 3, yellow: −2, red: −5), aggregated per player/season via the `player_season_scores` view; player detail screen shows season totals and match history; team leaderboard ranks players by points
- **Subscription plans** — Free (1 team / 2 matches), Pro (1 team / unlimited matches), Plus (3 teams / unlimited matches); plan limits enforced both app-side and server-side (`enforce-plan-limit` Edge Function); Stripe Checkout for upgrades (`create-checkout-session` + `stripe-webhook` Edge Functions); plan badge on Home/Settings and upgrade gate UI

## Not yet implemented (see roadmap)

- Team membership & invites (V2)
- League system (V6)
- Admin/manager analytics web platform (V7)

## Tech stack

- **Flutter** (Android + iOS)
- **Supabase** — PostgreSQL database, Auth, Row Level Security, Edge Functions
- **Riverpod** (`flutter_riverpod`) — state management
- **GoRouter** — navigation with auth redirect
- **Stripe** — subscription payments, via Supabase Edge Functions
- **flutter_local_notifications** — halftime / match-end alerts

## Getting started

### Prerequisites

- Flutter SDK
- A [Supabase](https://supabase.com) project with the schema from `supabase/migrations/` applied

### Environment variables

Create a `config.json` at the repo root (already in `.gitignore`):

```json
{
  "SUPABASE_URL": "your-supabase-project-url",
  "SUPABASE_ANON_KEY": "your-supabase-anon-key"
}
```

### Run

```bash
flutter pub get
flutter run --dart-define-from-file=config.json
```

### Analyze & test

```bash
flutter analyze
flutter test
flutter test integration_test/all_tests.dart
```

## Database

All migrations are in `supabase/migrations/`, applied in order via the Supabase CLI:

```bash
supabase db push
```

| Migration | Adds |
|---|---|
| `20260219224500_init_schema` | `teams`, `players`, `matches`, `match_player_stats` (owner-only RLS) |
| `20260614000000_v1_user_teams` | `profiles` (username, plan, role), username-based login lookup |
| `20260614000001_v1_matches_teams` | Sport/format columns on `teams`, player number/alias |
| `20260615193544_v1_plan_roles` | `role` column (`user` / `manager` / `admin`) + admin/manager read-all policy |
| `20260620000001_v3_matches` | Match status/timing columns, `stat_events`, `stat_rules` |
| `20260620000002_v4_subscriptions` | `subscriptions` table (Stripe customer/subscription/plan) |
| `20260701000000_v5_player_scoring` | `player_season_scores` view (points aggregated from `stat_events` via `stat_rules`) |

Row Level Security is enabled on all tables — trainers can only access data belonging to their own teams.

## Edge Functions

`supabase/functions/`:

- **`enforce-plan-limit`** — server-side check before team/match creation; blocks inserts over the caller's plan limit (bypassed for `admin` role)
- **`create-checkout-session`** — starts a Stripe Checkout session for plan upgrades
- **`stripe-webhook`** — listens for `checkout.session.completed` / `customer.subscription.updated`, updates `subscriptions` and `profiles.plan`

## Project structure

```
lib/
  main.dart                  # app entry point
  core/
    config/                  # env var access (AppConfig)
    router/                  # GoRouter + auth redirect
    theme/                   # Material 3 theme (seed #0B6E4F)
    utils/                   # form validators
  features/
    auth/                    # login, register, forgot password, profile
    home/                    # team list screen
    teams/                   # team detail, create team, roster, leaderboard
    players/                 # add/edit player, player detail, season scores
    matches/                 # create match, live match, match summary, stat rules
    subscriptions/           # plan model, subscription screen, gate UI
    settings/                # profile, plan badge, sign out
  shared/
    widgets/                 # reusable UI components
test/                        # unit & widget tests
integration_test/            # end-to-end flow tests (auth, home, teams, settings, subscription)
supabase/
  migrations/                # SQL schema history (see table above)
  functions/                 # Edge Functions (see above)
```

## Roadmap

See [`docs/versions.md`](docs/versions.md) for the full implementation plan across versions.

| Version | Status | Scope |
|---------|--------|-------|
| V0 | Done | Auth, team list, player roster (Football 11) |
| V1 | Done | Username login, multi-sport teams, full player management, roles |
| V2 | Planned | Team membership & invites |
| V3 | Done | Live match timer & real-time stat recording |
| V4 | Done | Subscription plans, plan enforcement & Stripe payments |
| V5 | Done | Player scoring, leaderboards, match history |
| V6 | Planned | League system |
| V7 | Planned | Admin/manager analytics web platform |
