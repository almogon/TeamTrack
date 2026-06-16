# Versions

---

## Version 0 — Scaffold (done)

**Goal:** Auth + single Football 11 team with a player roster.

### Backend
- Schema: `teams`, `players`, `matches`, `match_player_stats` with RLS (owner-only policies)
- Auth via Supabase (email + password); username stored in `user_metadata`

### Frontend
- Login / Register screens
- Home: team list (empty state → create team)
- Settings: create team (Football 11 only), user profile, sign out
- Team detail: player roster

---

## Version 1 — User identity & multi-sport teams

**Goal:** Robust user system, sport types, team formats, and full player management.

### Design decisions
- Login must accept **username or email** (Supabase Auth only supports email; workaround: look up email by username in `profiles` before signing in)
- Sport types and formats are fixed enums in the DB (not a config table) for V1
- Player positions are sport-specific (Football: GK/DEF/MID/FWD; Basketball: PG/SG/SF/PF/C; Volleyball: S/OH/MB/OPP/L)
- Subscription plan is stored in `profiles`; enforcement is app-side in V1 (DB-side edge function in V3)

### Backend
**New migration: `v1_user_teams`**
- `profiles` table
  ```
  id uuid PK → auth.users(id)
  username text UNIQUE NOT NULL
  display_name text
  avatar_url text
  plan text NOT NULL DEFAULT 'free'  -- free | pro | plus
  role text NOT NULL DEFAULT 'user'  -- user | manager | admin
  created_at, updated_at
  ```
  - RLS: select own, update own; admin/manager can select all
  - Trigger: auto-insert row on `auth.users` INSERT (via `handle_new_user` function)

- `team_members` table
  ```
  id uuid PK
  team_id uuid → teams(id)
  user_id uuid → auth.users(id)
  role text NOT NULL  -- owner | member
  joined_at timestamptz
  UNIQUE (team_id, user_id)
  ```
  - RLS: select if member, insert/delete if owner of the team

- Alter `teams`:
  - Add `sport text NOT NULL DEFAULT 'football'` — `football | basketball | volleyball`
  - Add `format text NOT NULL DEFAULT '11'` — e.g. `5`, `7`, `11` for football; `5` for basketball
  - Add `min_players int`, `max_players int` (populated by trigger/check per sport+format)

- Alter `players`:
  - Add `alias text` (public nickname, can be set by linked user)
  - Add `user_id uuid REFERENCES auth.users(id)` (nullable — only if player is a registered user)
  - Add `number int` UNIQUE per team (add unique constraint `(team_id, number)`)
  - `position` already exists; enforce allowed values per sport via app layer in V1

- Update RLS on `teams` / `players`: members can SELECT their team; only owner can INSERT/UPDATE/DELETE

**Plan limits (app-side check before insert):**
| Plan | Max teams (owned) | Max matches per team |
|------|-------------------|----------------------|
| free | 1                 | 2 (trial)            |
| pro  | 1                 | unlimited            |
| plus | 3                 | unlimited            |

### Frontend
- **Auth**
  - Register: add username field; create `profiles` row after sign-up
  - Login: accept username or email (resolve email from `profiles` if input has no `@`)

- **Create Team screen** (replace Football-11-only form)
  - Step 1: pick sport (Football / Basketball / Volleyball)
  - Step 2: pick format (options filtered by sport)
  - Step 3: name + season

- **Player management**
  - Add Player screen: name, alias, number, position picker (sport-aware), birthdate, photo
  - Edit / delete player
  - Player detail screen: profile card + stats summary (empty in V1)

- **Settings**
  - Show current plan badge
  - Show team count vs. limit
  - Show match count vs. limit (free plan: 2/2)

- **Providers / models**
  - `ProfileModel`, `ProfilesProvider`
  - `TeamMemberModel`, `TeamMembersProvider`
  - Update `TeamModel` (sport, format, min/max players)
  - Update `PlayerModel` (alias, user_id, number)

---

## Version 2 — Team membership & invites

**Goal:** A user can participate in teams they do not own.

### Design decisions
- Invite by username (no email sent in V1 — just a code or in-app accept flow)
- Member can view team and players; only owner can edit roster

### Backend
**New migration: `v2_invites`**
- `team_invites` table
  ```
  id uuid PK
  team_id uuid → teams(id)
  invited_by uuid → auth.users(id)
  invited_username text  -- target username
  status text DEFAULT 'pending'  -- pending | accepted | rejected
  created_at timestamptz
  ```
  - RLS: owner can insert; invited user (matched by `profiles.username`) can update status; owner can delete

- Update RLS on `teams` SELECT: use `team_members` instead of `owner_id = auth.uid()`
- `team_members` INSERT: triggered when invite is accepted

### Frontend
- **Invite screen**: owner types username → creates invite row
- **Notifications / pending invites**: home screen badge or dedicated screen listing pending invites
- **Accept / reject invite** flow
- Member team view: read-only roster (no add/edit/delete player)

---

## Version 3 — Live match & stats

**Goal:** Start a match, record stats per player in real time, match timer with period breaks.

### Design decisions
- Match timer runs client-side (Flutter Timer); server only stores `started_at`, `paused_at`, `status`
- Stats are upserted to `match_player_stats` immediately on each action (no batch save)
- Sport-specific stat types (Football: goals, assists, yellow, red, shots; Basketball: points, rebounds, assists, fouls; Volleyball: serves, blocks, errors)
- Period breaks are rule-based per sport: Football 11 → 45 min halftime; Football 5/7 → 25 min; Basketball → 4×10 min quarters; Volleyball → set-based
- Push notification via `flutter_local_notifications` for halftime / end

### Backend
**New migration: `v3_matches`**
- Alter `matches`:
  - Add `status text NOT NULL DEFAULT 'scheduled'` — `scheduled | live | paused | finished`
  - Add `started_at timestamptz`, `finished_at timestamptz`, `paused_at timestamptz`
  - Add `period int NOT NULL DEFAULT 1` (current half / quarter / set)

- `stat_events` table (append-only event log for live recording):
  ```
  id uuid PK
  match_id uuid → matches(id)
  player_id uuid → players(id)
  stat_type text NOT NULL  -- goal | assist | yellow | red | shot | save | fault | ...
  minute int  -- match minute when event happened
  value int NOT NULL DEFAULT 1
  recorded_at timestamptz DEFAULT now()
  ```
  - RLS: owner of the match's team can INSERT/SELECT; no UPDATE/DELETE (events are immutable)
  - A DB function `rebuild_match_player_stats(match_id)` aggregates events → `match_player_stats`

- Stat point values (stored as a reference table, not hard-coded):
  ```
  stat_rules (sport text, stat_type text, points int)
  -- e.g. ('football', 'goal', 5), ('football', 'assist', 3), ...
  ```

### Frontend
- **Match creation screen**: pick opponent, home/away, competition, date → status = `scheduled`
- **Match list screen** on Team Detail (upcoming + past)
- **Live match screen**:
  - Visual player grid by position (photo or initials + number)
  - Tap player → stat picker modal (sport-aware stat list)
  - Match timer header (MM:SS) with period indicator
  - Pause / resume / end match buttons
  - Scoreboard (running score based on events)
- **Match summary screen** (post-match): full stat table per player + calculated points
- **Local notifications**: halftime and match-end alerts
- **Providers / models**
  - `MatchModel`, `MatchProvider`, `MatchListProvider`
  - `StatEventModel`, `LiveMatchNotifier` (manages timer + event stream)
  - `StatRulesProvider`

---

## Version 4 — Subscription & payments

**Goal:** Enforce plan limits server-side and allow users to upgrade.

### Design decisions
- Payment provider: **Stripe** (via Supabase Edge Function webhook)
- Plans enforced in a Supabase Edge Function on team insert (not just app-side)
- No native in-app purchase in V4 — redirect to a web checkout page

### Backend
- `subscriptions` table:
  ```
  user_id uuid PK → auth.users(id)
  stripe_customer_id text
  stripe_subscription_id text
  plan text NOT NULL DEFAULT 'free'
  current_period_end timestamptz
  ```
- Supabase Edge Function `stripe-webhook`: listens for `checkout.session.completed` and `customer.subscription.updated` → updates `subscriptions` and `profiles.plan`
- Edge Function `enforce-plan-limit`: called before team or match insert; returns 403 if over team or match limit for the plan
- Update RLS / policies so plan check can run as `service_role` in the edge function

### Frontend
- **Subscription screen**: current plan card, feature comparison table, upgrade CTA → opens Stripe Checkout in WebView / browser
- **Plan badge** on home screen and settings
- **Gate UI**: show upgrade prompt when user tries to create a team over their limit

---

## Version 5 — Player scoring & history

**Goal:** Aggregate stats into player scores, season leaderboards, and match history.

### Design decisions
- Season score = sum of points across all matches for that season
- Leaderboard scoped per team per season
- Player history shows per-match breakdown

### Backend
- DB view or materialized view `player_season_scores`:
  ```sql
  SELECT p.id, p.team_id, m.season (from team), SUM(points) as total_points
  FROM match_player_stats mps
  JOIN stat_rules sr ON ...
  JOIN players p ON ...
  GROUP BY ...
  ```
- Function `compute_player_points(match_id)` → updates a `points` column on `match_player_stats`

### Frontend
- **Player detail screen** (expanded from V1): season stats, total points, match history list
- **Leaderboard screen** on Team Detail: ranked list of players by points for selected season
- **Match history screen**: list of past matches with score + top performer
- **Match summary** (expand V3): show MVP (highest points in match)

---

## Version 6 — League system

**Goal:** Allow groups of teams to compete in a structured seasonal league.

### Design decisions
- Any user can request to create a league, but it must be validated by an `admin` or `manager` before it becomes active
- League season always runs **1 July → 30 June** (fixed calendar, not configurable in V6)
- A team can belong to only one league at a time
- When a league season ends, the system auto-creates the next season's edition in `default_leagues` so the league persists without manual recreation
- Teams discover leagues by city or zip code

### Backend
**New migration: `v6_leagues`**
- `leagues` table
  ```
  id uuid PK
  name text NOT NULL
  city text NOT NULL
  zip_code text NOT NULL
  season text NOT NULL  -- e.g. '2026-2027'
  status text NOT NULL DEFAULT 'pending'  -- pending | active | finished
  created_by uuid → auth.users(id)
  validated_by uuid → auth.users(id)  -- set by admin/manager on approval
  created_at timestamptz
  ```
  - RLS: any authenticated user can INSERT (pending); admin/manager can UPDATE status; all can SELECT active

- `league_teams` table
  ```
  league_id uuid → leagues(id)
  team_id uuid → teams(id)
  joined_at timestamptz
  PRIMARY KEY (league_id, team_id)
  UNIQUE (team_id)  -- one league per team
  ```
  - RLS: team owner can insert; admin/manager or owner can delete

- `default_leagues` table (canonical registry for auto-renewal)
  ```
  id uuid PK
  name text NOT NULL
  city text NOT NULL
  zip_code text NOT NULL
  -- Each season a new row is inserted in `leagues` referencing this record
  ```

- DB function `rollover_leagues()`: called at season end (or via scheduled Edge Function); inserts next-season rows into `leagues` for every active entry in `default_leagues`

### Frontend
- **Discover leagues screen**: search by city or zip code; list of active leagues with join button
- **Create league screen**: name, city, zip code → status = `pending`; user sees "awaiting validation" state
- **League detail screen**: standings table, list of member teams, season dates
- **Admin validation flow** (admin/manager role only): pending league list → approve / reject
- Update **team detail screen**: show current league badge if enrolled

---

## Version 7 — Admin & manager analytics platform

**Goal:** A web platform (separate from the trainer app) accessible only to `admin` and `manager` users, offering cross-team and cross-league analytics.

### Design decisions
- Separate web app (Next.js or similar), authenticated via the same Supabase project
- Access gated by `profiles.role IN ('admin', 'manager')`; enforced via RLS and Edge Function middleware
- Read-only in V7 (no data mutation from this platform)
- Depends on V6 (leagues) and V5 (player scores)

### Backend
- No new tables required; platform queries existing views and tables
- New DB view `platform_top_players`: cross-team ranking by total season points (all leagues)
- New DB view `platform_league_standings`: per-league team standings with win/draw/loss/points
- Edge Function `admin-auth-check`: validates `manager` or `admin` role on every API call from the platform

### Frontend (web platform)
- **Dashboard**: summary cards — total active leagues, total teams, total players, top scorer of the week
- **League browser**: all leagues with standings and team lists
- **Player leaderboard**: global ranking by season points, filterable by league / sport / season
- **Team analysis**: per-team stat breakdown, player performance comparison
- **Pending validations panel** (admin only): approve/reject league creation requests

---

## Backlog / Future

- Multiple seasons per team
- Player photo upload (Supabase Storage)
- Team avatar
- Dark mode
- Volleyball set-based scoring logic
- Basketball quarter timer
- Export match report (PDF)
- Coach notes per match
- Public team profile page (web)
