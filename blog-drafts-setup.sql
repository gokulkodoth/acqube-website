-- Acqube: let the automatic blog writer save DRAFT articles (it can never publish).
-- Run once in Supabase -> SQL Editor. Safe to run again.

create schema if not exists private;                 -- not exposed through the website API
create table if not exists private.secrets (name text primary key, value text not null);
revoke all on schema private from anon, authenticated;

-- a long random key, created once
insert into private.secrets (name, value)
values ('blog_draft', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (name) do nothing;

create or replace function public.submit_blog_draft(
  p_secret text, p_title text, p_category text, p_excerpt text, p_body text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if p_secret is null or p_secret <> (select value from private.secrets where name = 'blog_draft') then
    raise exception 'not allowed';
  end if;
  if exists (select 1 from posts where lower(trim(title)) = lower(trim(p_title))) then
    raise exception 'an article with this title already exists';
  end if;
  insert into posts (title, category, excerpt, body, status, updated_at)
  values (trim(p_title), coalesce(nullif(trim(p_category), ''), 'General'),
          left(trim(p_excerpt), 300), p_body, 'Draft', now())   -- always a draft
  returning id into v_id;
  return v_id::text;
end $$;

revoke all on function public.submit_blog_draft(text, text, text, text, text) from public;
grant execute on function public.submit_blog_draft(text, text, text, text, text) to anon;

-- Shows the key to copy into GitHub (Settings -> Secrets -> Actions -> BLOG_DRAFT_SECRET).
-- Do not share it in chat.
select value as blog_draft_secret from private.secrets where name = 'blog_draft';
