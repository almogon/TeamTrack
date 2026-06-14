-- V1: profiles, multi-sport teams, full player fields

-- 1. profiles table
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text unique not null check (char_length(trim(username)) >= 3),
  display_name text,
  avatar_url   text,
  plan         text not null default 'free' check (plan in ('free', 'plus', 'pro')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy profiles_select_own on public.profiles
  for select using (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- auto-create profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'username',
      'user_' || substr(new.id::text, 1, 8)
    )
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- resolve email by username (used for username-based login; runs as service role)
create or replace function public.get_email_by_username(p_username text)
returns text
language sql
security definer set search_path = public
as $$
  select u.email
  from auth.users u
  join public.profiles p on p.id = u.id
  where lower(p.username) = lower(p_username)
  limit 1;
$$;

-- check username availability before sign-up (callable by anon)
create or replace function public.is_username_available(p_username text)
returns boolean
language sql
security definer set search_path = public
as $$
  select not exists (
    select 1 from public.profiles
    where lower(username) = lower(p_username)
  );
$$;

grant execute on function public.get_email_by_username(text) to anon, authenticated;
grant execute on function public.is_username_available(text) to anon, authenticated;

-- 2. Alter teams: sport, format, min/max players
alter table public.teams
  add column if not exists sport text not null default 'football'
    check (sport in ('football', 'basketball', 'volleyball')),
  add column if not exists format text not null default '11',
  add column if not exists min_players int,
  add column if not exists max_players int;

-- 3. Alter players: alias, user_id, unique number per team
alter table public.players
  add column if not exists alias text,
  add column if not exists user_id uuid references auth.users(id) on delete set null;

alter table public.players
  drop constraint if exists players_team_number_unique;

alter table public.players
  add constraint players_team_number_unique unique (team_id, number);
