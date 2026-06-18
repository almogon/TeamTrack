-- V1 patch: add role column to profiles; admin/manager can read all profiles

alter table public.profiles
  add column if not exists role text not null default 'user'
    check (role in ('user', 'manager', 'admin'));

-- Helper function (security definer to bypass RLS for the role check itself)
create or replace function public.is_admin_or_manager()
returns boolean
language sql
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('admin', 'manager')
  );
$$;

grant execute on function public.is_admin_or_manager() to authenticated;

-- Allow admin/manager users to read all profiles (needed for V7 analytics platform)
create policy profiles_select_admin on public.profiles
  for select using (public.is_admin_or_manager());
