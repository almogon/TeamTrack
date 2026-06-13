# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TeamTrack is a Flutter mobile app (Android + iOS) for sports team trainers. A trainer can create and manage teams, register players, run matches, and record live stats per player.

Backend: **Supabase** (PostgreSQL + Auth). No separate server — all data access goes through the Supabase Flutter SDK.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on a device/emulator (Supabase env vars required)
flutter run \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>

# Analyze
flutter analyze

# Tests
flutter test
flutter test test/unit/       # unit tests only
flutter test test/widget/     # widget tests only
```

`AppConfig.validate()` is called at startup and throws if either env var is missing — the app will not launch without them.

## Project structure

```
F:\Development\bemanager\          # repo root (also Flutter project root)
  pubspec.yaml                     # Flutter manifest & dependencies
  analysis_options.yaml            # Dart linting rules
  devtools_options.yaml            # Dart DevTools config
  CLAUDE.md                        # this file
  README.md
  .vscode/
    launch.json                    # VS Code debug config with --dart-define presets
  .claude/
    settings.local.json            # Claude Code harness settings (not committed)
  docs/                            # design & API docs
    swagger.yml
    diagrama_clases_alvaro.drawio
    entidad_relacion_alvaro.drawio.png
  client/docs/                     # UI notes
    notas.txt
    ui_interfaces.txt
  supabase/
    migrations/
      20260219224500_init_schema.sql   # full schema: teams, players, matches, match_player_stats
  android/                         # Android platform shell
  ios/                             # iOS platform shell
  lib/
    main.dart                      # Supabase init, ProviderScope, MaterialApp.router
    core/
      config/app_config.dart       # SUPABASE_URL / SUPABASE_ANON_KEY via --dart-define
      router/app_router.dart       # GoRouter (7 routes) + auth redirect via AuthNotifier
      theme/app_theme.dart         # Material 3, seed colour #0B6E4F
      utils/validators.dart        # Form validator helpers
      navigation/                  # (reserved, empty)
      providers/                   # (reserved, empty)
    features/
      auth/
        notifiers/auth_notifier.dart   # ChangeNotifier wrapping Supabase auth stream
        screens/login_screen.dart
        screens/register_screen.dart   # stores username in user_metadata
        data/                          # (reserved, empty)
        presentation/                  # (reserved, empty)
      home/
        screens/home_screen.dart       # team list; empty state → create team
      teams/
        models/team.dart               # id, owner_id, name, season, createdAt
        models/player.dart
        providers/teams_provider.dart  # AsyncNotifier; createTeam() invalidates self
        providers/team_provider.dart   # FutureProvider.family; fetches team + players
        screens/create_team_screen.dart
        screens/team_detail_screen.dart
        data/ domain/ presentation/    # (reserved, empty)
      settings/
        screens/settings_screen.dart   # profile, create team, sign out
      matches/                         # (reserved, empty — future feature)
      players/                         # (reserved, empty — future feature)
      stats/                           # (reserved, empty — future feature)
    shared/
      widgets/primary_button.dart      # FilledButton with loading state
  test/
    validators_test.dart
    widget_test.dart
    unit/                          # (empty)
    widget/                        # (empty)
```

## Architecture

### State management

- **Riverpod** (`flutter_riverpod`): all providers live in `features/<name>/providers/`
- **Navigation**: `go_router` with redirect guarded by `AuthNotifier` (a `ChangeNotifier` passed as `refreshListenable`)
- Auth redirect logic is in `app_router.dart`: unauthenticated → `/login`; authenticated on auth routes → `/home`

### Supabase

- Client accessed via `Supabase.instance.client` (no wrapper needed)
- Username stored in `auth.user.user_metadata['username']` at registration
- RLS is enabled on all tables — policies enforce `owner_id = auth.uid()`

### Database schema

Migration: `supabase/migrations/20260219224500_init_schema.sql`

Tables: `teams`, `players`, `matches`, `match_player_stats`

`match_player_stats` columns: `minutes`, `goals`, `assists`, `yellow`, `red`, `shots`, `saves`

Stat point values (to be applied in the app layer for V1):
- goal: 5 pts, assist: 3 pts, yellow card: −2 pts, red card: −5 pts

## Version 0 scope

- Login + Register screens
- Home: list of trainer's teams
- Settings: create team (Football 11), user profile, sign out
- Team detail: player roster

Future versions will add: match creation, live stat recording, player scoring/evaluation, sport types (basketball, volleyball), team formats (5/7/11), subscription tiers.
