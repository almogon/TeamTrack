# TeamTrack

A Flutter mobile app for sports trainers to manage teams, players, and match statistics in real time.

## Features

- **Multi-sport support** — Football (5/7/11), Basketball, Volleyball
- **Team management** — Create and manage teams, add players with positions and numbers
- **Live match recording** — Start a match, track the timer, and log player stats on the fly
- **Player scoring** — Stats are converted to points (goals, assists, cards, etc.) and aggregated per player per season
- **Team membership** — Invite registered users to join your team as participants
- **Subscription plans** — Free (1 team), Plus (3 teams), Pro (5 teams)

## Tech stack

- **Flutter** (Android + iOS)
- **Supabase** — PostgreSQL database, Auth, Row Level Security, Storage
- **Riverpod** — state management
- **GoRouter** — navigation with auth redirect

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
```

## Database

All migrations are in `supabase/migrations/`. Apply them in order against your Supabase project via the Supabase CLI:

```bash
supabase db push
```

Row Level Security is enabled on all tables — every user can only access data belonging to their own teams.

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
    auth/                    # login & register screens
    home/                    # team list screen
    teams/                   # team detail, create team, player roster
    matches/                 # (V3) live match screen
    players/                 # (V1) player detail & management
    stats/                   # (V3) stat recording & history
    settings/                # profile, plan, sign out
  shared/
    widgets/                 # reusable UI components
```

## Roadmap

See [`docs/versions.md`](docs/versions.md) for the full implementation plan across versions.

| Version | Status | Scope |
|---------|--------|-------|
| V0 | Done | Auth, team list, player roster (Football 11) |
| V1 | Planned | Username login, multi-sport teams, full player management |
| V2 | Planned | Team membership & invites |
| V3 | Planned | Live match timer & real-time stat recording |
| V4 | Planned | Subscription plans & Stripe payments |
| V5 | Planned | Player scoring, leaderboards, match history |
