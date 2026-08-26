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
| Plan | Max teams (owned + member) | Max matches per team |
|------|---------------------------|----------------------|
| free | 1                         | 2 (trial)            |
| pro  | 1                         | unlimited            |
| plus | 3                         | unlimited            |

> The team cap counts **all** teams the user belongs to — whether they own the team or joined it via invite. This limit is enforced on team creation (V1) and on invite acceptance (V2).

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
- **Plan limit check on accept**: before inserting into `team_members`, count all teams the invited user already belongs to (owned + member). If the count equals or exceeds their plan limit, the accept is blocked and a plan-upgrade prompt is shown. The invite row stays `pending` — the user can upgrade and accept later.

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
- `team_members` INSERT: triggered when invite is accepted, **only after** the app-side plan limit check passes
- Helper query for the plan check (runs before accepting):
  ```sql
  SELECT COUNT(*) FROM team_members WHERE user_id = <invited_user_id>;
  -- compare result against profiles.plan limit (free/pro → 1, plus → 3)
  ```

### Frontend
- **Invite screen**: owner types username → creates invite row
- **Notifications / pending invites**: home screen badge or dedicated screen listing pending invites
- **Accept / reject invite** flow
  - On tap "Accept": fetch the user's current team count and plan limit
  - If count < limit → proceed; insert `team_members` row, mark invite `accepted`
  - If count ≥ limit → block the accept, show an inline error: _"You've reached the [plan] plan limit of [N] team(s). Upgrade your plan to join more teams."_ with an **Upgrade** CTA; invite remains `pending`
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
- When a league season ends, the system auto-creates the next season's edition in `default_leagues` so the league persists without manual recreation, but the league stay empty without any team relation.
- a Team should have the option to join a league, only if is not already linked with an other one.
- If one team join a league, this team can not leave it, so before join a league, the user should get a notification to confirm wants to join.
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

### Implementation notes
- `league_teams_delete` RLS is **admin/manager only** — there is no owner self-leave, per the "cannot leave" design decision above. The Discover Leagues screen shows a confirmation dialog ("Once your team joins ... it cannot leave") before inserting the `league_teams` row.
- Rejecting a pending league request is a **delete** (no `rejected` status exists in the schema); approving sets `status = 'active'` + `validated_by`.
- **Standings** are computed by `league_standings(p_league_id)`, a `SECURITY DEFINER` SQL function, not a plain view — `matches` RLS is owner-only, so a caller can't see another team's match rows directly; the function aggregates win/draw/loss/points server-side and returns only those columns, without exposing raw match data cross-team. Each team's record is built from that team's own logged matches (no cross-team dedup, consistent with `player_season_scores`).
- `rollover_leagues()` is **not exposed to the app** (no grant to `authenticated`) — it's meant to be invoked via the SQL editor, a scheduled Edge Function, or `pg_cron`; none of those triggers are wired up yet, so rollover is a manual/operational step for now. `default_leagues` is likewise DB-only (admin/manager RLS), with no management UI in this version.
- Admin entry point: Settings → "Admin" section (visible only when `profile.role` is `admin`/`manager`) → `/admin/leagues`.
- Team detail screen: shows "Join a league" + "Request a league" buttons when the team has none, or a league chip (→ League Detail) when it does.

---

## Others: Admin & manager analytics platform

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


## Main Menu implementation

**Goal:** Replace the plain team-list Home screen with the visual "main menu" dashboard from `docs/design/main-menu/menu.png` / `menu.md`: a formation view of the current team's players, a carousel when the trainer owns multiple teams, and an oval footer with quick actions.

### Design decisions
- This is a frontend-only reshape of the existing Home screen — no new tables, no new providers beyond what `teamsProvider` / `teamDetailProvider` already expose.
- **Empty state** (no teams): a single large circular button with a plus icon, centered — replaces the old icon+text+button empty state.
- **One team**: show a formation view of that team's active players.
- **Multiple teams**: the formation view becomes a swipeable `PageView` carousel (one page per team) with small page-indicator dots; footer actions apply to whichever team page is currently visible. Wrapped in a `ScrollConfiguration` that adds `PointerDeviceKind.mouse` to `dragDevices` — Flutter's default `ScrollBehavior` only allows touch/stylus/trackpad to drag-scroll (mouse is excluded by default, reserved for text selection), so click-and-drag with a mouse silently did nothing until this was added.
- **Formation layout (superseded by Line-Up management below)**: originally, players were grouped purely by their own `position` field (reverse of `sport_type.dart`'s `Position` list — football: FWD → MID → DEF → GK). Once the Line-Up tab landed, the main menu was switched to render the team's **actual saved line-up** instead (same formation shape and slot assignments as the Line-Up tab, including placeholders for empty slots), so the two views always show the identical disposition — see Line-Up management. Players are still drawn as tappable diamonds (rotated squares) showing shirt number; tapping a filled slot opens the player detail screen, tapping a placeholder does nothing (editing only happens in the Line-Up tab).
- Diamonds use the app's theme primary color (not the mockup's placeholder orange) to stay consistent with the rest of the UI.
- **Top bar**: keep the existing plan-badge chip alongside the settings icon (top right, per design) — dropping it would be a regression with no benefit.
- **Oval footer** (per mockup, left → right):
  - Left icon (list glyph) → **Scores**: opens Team Detail on the existing Leaderboard tab (`TeamDetailScreen` gains an `initialTabIndex` constructor param, passed via route `extra`).
  - Middle icon (pitch glyph) → **Start a match**: opens the existing Create Match screen (`/teams/:teamId/matches/new`). No "is there already a live match" branching in this version — always goes to create.
  - Right icon (players glyph) → **Edit positions and players**: opens Team Detail on the Roster tab (default tab 0). Position editing itself reuses the existing sport-aware position picker on the Add/Edit Player screen — no separate drag-and-drop formation editor in this version.

### Frontend
- `lib/features/teams/models/sport_type.dart`: add `SportType.formationOrder` (reversed `positions` list).
- `lib/shared/widgets/player_diamond.dart`: `PlayerDiamond` (rotated-square tappable token showing shirt number) — originally lived under `home/widgets/`, moved to `shared/` once the Line-Up tab needed to reuse it too (see Line-Up management).
- `lib/features/home/widgets/main_menu_footer.dart`: `MainMenuFooter`, the oval `StadiumBorder` bottom bar with the 3 actions above.
- `lib/features/home/screens/home_screen.dart`: rewritten — empty/single/carousel states as described above, footer wired to the active team. (Its formation rendering was later swapped to `LineupGridView`; see Line-Up management.)
- `lib/features/teams/screens/team_detail_screen.dart`: `TeamDetailScreen` gains `initialTabIndex` (default `0`); `DefaultTabController` uses it as `initialIndex`.
- `lib/core/router/app_router.dart`: `/teams/:teamId` route reads `state.extra as int?` for the initial tab index.

---

## Line-Up management

**Goal:** Let a trainer pick a formation shape (e.g. 4-4-2, 4-3-3) for their team and assign specific players to each slot, from a new "Line-Up" tab on Team Detail. The main menu shows the chosen formation's name under the team's sport/format label.

### Design decisions
- The list of available formations (which shapes exist, and which position each slot represents) is a **hardcoded Dart list**, not a DB table — formations are a fixed piece of app logic, not data a trainer edits, so fetching them from the database would just be network latency for no benefit.
- What's *chosen* and *who's assigned* are per-team state and must persist across sessions/devices, so that part **does** live in the DB: `teams.lineup_formation` (which shape is selected) + a new `lineup_slots` table (which player, if any, occupies each slot).
- A slot holds at most one player; assigning a player who already occupies another slot moves them (no duplicates). A slot can be empty — rendered as a dashed placeholder diamond.
- **Changing formation smart-remaps instead of resetting**: players keep their own role's slots where possible (e.g. DEF stays DEF). When a role shrinks, the overflow cascades *forward* (toward attack) into the next role that has room — e.g. 4-4-2 → 4-3-3 keeps all 4 DEF, keeps 3 of the 4 MID in place, and the 4th MID moves into the new 3rd FWD slot. Overflow that still doesn't fit after the most attacking role falls back to the bench. See `LineupFormation.remapAssignments`.
- Slot assignment is **free-form**: a trainer can put any active player in any slot, regardless of that player's own `position` field. The formation only fixes *how many* slots of each role exist and where they sit in the layout, not who's allowed in them.
- **Everything is local/pending until "Save"** — picking a formation, moving players, and reassigning slots only touch in-memory widget state; nothing reaches Supabase until the Save button is tapped, which persists `teams.lineup_formation` and replaces all `lineup_slots` rows for the team in one go. Leaving the tab (or the screen) without saving discards the pending edits — there's no unsaved-changes prompt in this version.
- Active players not currently placed in a slot are listed in a **Bench** section below the grid (a team can have up to 18 players), using the existing player-list style. Assignment has two equivalent paths: tap a slot to open the player-picker sheet (which also shows each player's `position`), or drag a bench player directly onto a slot — both call the same `_assignPlayerToSlot` logic, so there's one source of truth for "what happens when a player is assigned," just two ways to trigger it.
- Bench items use a plain `Draggable` (immediate drag on pointer-down), not `LongPressDraggable`. `LongPressDraggable` was tried first to avoid competing with scrolling a long bench list, but its ~500ms hold-before-drag made it look completely broken with a normal mouse click-and-drag (the main way this app gets tested in this environment) — nothing happened unless you held first, which isn't an obvious first move on desktop. Immediate `Draggable` trades a little touch-scroll friction over the bench (14+ players max, so a minor cost) for drag actually working the way a user expects to try it.
- **The main menu renders the exact same disposition as this tab**: same formation shape, same filled/placeholder slots — both share `LineupGridView` (`lib/features/teams/widgets/lineup_grid_view.dart`). The main menu shows whatever was last *saved*; unsaved edits made in the Line-Up tab aren't reflected there until Save is tapped. If a team has never saved a line-up, the main menu defaults to the sport's first hardcoded formation (all placeholders), matching the tab's own first-visit default (UC1) — this keeps the two views consistent instead of one showing a fallback and the other showing nothing. The main menu's grid is read-only: tapping a filled slot opens that player's detail screen (as before), tapping a placeholder does nothing — all editing stays in the Line-Up tab.
- Only football gets multiple real shapes (4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 3-4-3 for 11-a-side; 3-2-1/2-3-1/3-1-2 for 7-a-side; 2-1-1/1-2-1/2-2 for 5-a-side). Basketball and volleyball don't have an equivalent "formation" concept in this app, so each gets one flat, single-row shape covering all on-court positions.
- **Pitch background (first design pass)**: `LineupGridView` renders a stylized football half-pitch (`assets/pitches/football_half_pitch.svg`, via `flutter_svg`) behind the formation grid — goal line + penalty/six-yard boxes + corner arcs at the bottom (under the GK row), halfway line + center-circle arc at the top (above the forward line), since rows already render attack-first/defense-last (`formationOrder`). The SVG is stretched with `BoxFit.fill` inside a `Positioned.fill` sized by the grid's own `Stack`, so it's pixel-aligned to whatever the grid renders — no separate layout math to keep in sync. Football-only for now (`team.sportType == SportType.football` gate in `LineupGridView`); basketball/volleyball still render on a plain background. Because `LineupGridView` is the single shared widget behind both the main menu and the Line-Up tab, this backdrop appears in both places for free.

### Use cases
- **UC1 — Open the Line-Up tab for the first time**: no formation saved yet → the formation combobox defaults to the sport's first hardcoded option and the grid renders immediately (all placeholders) — there's no separate "pick before you see the grid" step.
- **UC2 — Change formation**: trainer picks a different option from the combobox → slots are recomputed by the smart-remap rule above (same-role players stay, overflow cascades forward, excess falls to the bench) → Save becomes enabled.
- **UC3 — Assign a player to a slot**: trainer taps an empty (or filled) slot → a sheet lists the team's active players, unassigned players first and already-assigned-elsewhere ones after (each row also shows their own `position` next to their name; current occupant checked). A row of position filter chips ("All" + the sport's own positions, e.g. GK/DEF/MID/FWD) narrows the list to just that position — tapping the active chip again clears the filter back to "All". Picking a player fills the slot locally; if they already occupied a different slot, that slot is cleared. A "Clear this slot" option empties a filled slot.
- **UC4 — Review the bench, or drag a bench player into a slot**: players not in any slot are listed under the grid so the trainer can see who's left out before saving. Each bench row is also draggable — dropping it on any slot (filled or empty) assigns that player there via the same logic as UC3 (the slot highlights while a drag hovers over it). Tap-to-pick (UC3) and drag-and-drop are two paths to the same assignment action, not separate states.
- **UC5 — Save**: trainer taps Save → the formation and all slot assignments are written to Supabase in one action; the button disables again until another change is made.
- **UC6 — See the current line-up from the main menu**: after saving, the trainer returns to the main menu (Home) → under the team's sport/format label (e.g. "Football 11"), the saved formation's name is shown (e.g. "4-3-3") and the same slot grid (filled players + placeholders for empty slots) renders below it, identical to what was just saved in the Line-Up tab.

### Backend
**New migration**
- Alter `teams`: add `lineup_formation text` (nullable; formation key like `'4-3-3'`, matched against the hardcoded frontend list — no DB-side validation of the value, since the valid set lives in the app)
- `lineup_slots` table
  ```
  team_id uuid → teams(id) on delete cascade
  slot_index int                 -- position within the chosen formation's slot list
  player_id uuid → players(id) on delete set null
  PRIMARY KEY (team_id, slot_index)
  ```
  - RLS mirrors the current (V1 `team_members` not yet implemented) owner-only policy already used by `teams`/`players`: owner of the team can SELECT/INSERT/UPDATE/DELETE their own team's slots.

### Frontend
- `lib/features/teams/models/lineup_formation.dart`: hardcoded `LineupFormation` list per sport + format (key, label, ordered list of position codes — list index = `slot_index`).
- `lib/features/teams/providers/lineup_provider.dart`: `teamLineupProvider(teamId)` — read-only (formation key + `slot_index → Player` map). In the Line-Up tab it's used once to seed local editing state (mutated locally, written back only by Save); on the main menu it's watched directly and rendered live (read-only, nothing to save there).
- `lib/features/teams/models/lineup_formation.dart`: also holds `LineupFormation.remapAssignments`, the smart-remap algorithm used on formation change.
- `lib/features/teams/widgets/lineup_grid_view.dart`: `LineupGridView` — the shared formation-shape grid (rows of `PlayerDiamond` / placeholder diamonds, per `formationOrder`), taking an `onSlotTap` callback so the same widget can be interactive (Line-Up tab) or read-only-ish (main menu, where it only reacts to filled slots).
- `lib/features/teams/screens/team_detail_screen.dart`: new **Line-Up** tab between Roster and Matches (tab count 3 → 4).
- `lib/features/home/screens/home_screen.dart`: renders `LineupGridView` fed by `teamLineupProvider` instead of the original position-auto-grouped view (see the Main Menu section's note above).

#### Improvements and bugs 1
Remove line-up 4-2-3-1
soccer field change when the layers of the line-up are different. Let the size to cover the biggest line-up and adapt the position of the players correctly into that.
Soccer field has the half cycle of the top inverse in both football svgs
The footbal goal in svg football 7/11 
add line-up 3-3 in footbal 7 as first and default option
Hide options to create basketball and volleyball from the UI until we do the svg and other options
In the line-up management view, i want split the main view into two layers. for tablet or bigger screans
- First row with join a league and request a league we let.
- Then we have container left and container rigth:
-- Rigth: Display the formation and the soccer field
-- Left: Display the bench. This part should have the scroll, and the names should be ellipsed if they dont fit the size. 
- Containers can not be the same size, because football field should be big enough to see it correct.
For telephones screans:
first row:
formation combobox, and in the rigth align center position, an icon to open more settings (join a league, request a league)
The bench, instead of display number/playername, display only the number, and make an horizontal scroll only of this section.

#### Improvements and bugs 2
After finish the match, I can see correct the summary of the match and the points. However, when I navigate back, because is the only option to go away of this view, and come back until the Matches list, that match has the icon Start instead of the summary, and also the points are not added into Leaderboard statistics. So there is something missing, review and fix.