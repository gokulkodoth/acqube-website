-- =====================================================================
-- Acqube website: Supabase setup
-- Run once in Supabase → SQL Editor → New query → paste → Run.
-- Safe to re-run.
-- =====================================================================

-- ---------- Admin list ----------
create table if not exists public.admins (
  email text primary key
);
insert into public.admins (email) values ('gokul@acqube.com')
on conflict (email) do nothing;

-- true when the signed-in user's email is on the admin list
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------- Leads (website enquiries) ----------
create table if not exists public.leads (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  name           text not null check (char_length(name) between 1 and 120),
  mobile         text not null check (char_length(mobile) between 6 and 20),
  email          text check (email is null or char_length(email) <= 200),
  company        text check (company is null or char_length(company) <= 200),
  service        text check (service is null or char_length(service) <= 120),
  city           text check (city is null or char_length(city) <= 120),
  message        text check (message is null or char_length(message) <= 2000),
  preferred_time text check (preferred_time is null or char_length(preferred_time) <= 60),
  source         text check (source is null or char_length(source) <= 40),
  page           text check (page is null or char_length(page) <= 120),
  status         text not null default 'New' check (status in ('New','Contacted','Converted','Closed')),
  notes          text check (notes is null or char_length(notes) <= 2000)
);

-- ---------- Blog posts ----------
create table if not exists public.posts (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  published_at timestamptz,
  title        text not null check (char_length(title) between 1 and 200),
  category     text default 'General',
  excerpt      text check (excerpt is null or char_length(excerpt) <= 300),
  body         text not null,
  status       text not null default 'Draft' check (status in ('Draft','Published'))
);

-- ---------- Testimonials ----------
create table if not exists public.testimonials (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  name       text not null,
  company    text,
  location   text,
  service    text,
  rating     int not null default 5 check (rating between 1 and 5),
  text       text not null check (char_length(text) <= 800),
  consent    boolean not null default false,  -- client gave written permission
  published  boolean not null default false
);

-- ---------- Row Level Security ----------
alter table public.admins       enable row level security;
alter table public.leads        enable row level security;
alter table public.posts        enable row level security;
alter table public.testimonials enable row level security;

-- admins: nobody reads or edits this list from the website (manage it in the SQL editor)
drop policy if exists "no access" on public.admins;

-- leads: anyone may submit a new enquiry; only admins can see or change leads
drop policy if exists "public can submit leads" on public.leads;
create policy "public can submit leads" on public.leads
  for insert to anon, authenticated
  with check (status = 'New' and notes is null);

drop policy if exists "admins manage leads" on public.leads;
create policy "admins manage leads" on public.leads
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- posts: everyone reads published posts; admins read and write everything
drop policy if exists "public reads published posts" on public.posts;
create policy "public reads published posts" on public.posts
  for select to anon, authenticated
  using (status = 'Published' or public.is_admin());

drop policy if exists "admins manage posts" on public.posts;
create policy "admins manage posts" on public.posts
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- testimonials: everyone reads approved + published ones; admins manage all
drop policy if exists "public reads published testimonials" on public.testimonials;
create policy "public reads published testimonials" on public.testimonials
  for select to anon, authenticated
  using ((published and consent) or public.is_admin());

drop policy if exists "admins manage testimonials" on public.testimonials;
create policy "admins manage testimonials" on public.testimonials
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- table privileges (Supabase usually grants these already; kept explicit)
grant select, insert, update, delete on public.leads, public.posts, public.testimonials to authenticated;
grant insert on public.leads to anon;
grant select on public.posts, public.testimonials to anon;
