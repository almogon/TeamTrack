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
  plan text NOT NULL DEFAULT 'free'  -- free | plus | pro
  created_at, updated_at
  ```
  - RLS: select own, update own
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
| Plan | Max teams (owned or member) |
|------|-----------------------------|
| free | 1 |
| plus | 3 |
| pro  | 5 |

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
- Edge Function `enforce-plan-limit`: called before team insert; returns 403 if over limit
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
