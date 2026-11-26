-- Acqube: quotes & invoices for the admin console.  Run once in Supabase -> SQL Editor.  Safe to run again.

create table if not exists public.billing_docs (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  kind          text not null check (kind in ('quote','invoice')),
  number        text not null unique,
  doc_date      date not null default current_date,
  due_date      date,
  client        jsonb not null default '{}'::jsonb,
  items         jsonb not null default '[]'::jsonb,
  tax_mode      text not null default 'intra' check (tax_mode in ('intra','inter','none')),
  subtotal      numeric(14,2) not null default 0,
  tax_total     numeric(14,2) not null default 0,
  total         numeric(14,2) not null default 0,
  notes         text,
  terms         text,
  status        text not null default 'Draft'
                check (status in ('Draft','Sent','Accepted','Declined','Part paid','Paid','Cancelled')),
  share_token   text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  lead_id       uuid,
  source_quote  uuid references public.billing_docs(id) on delete set null,
  viewed_at     timestamptz,
  accepted_at   timestamptz,
  accepted_by   text,
  paid_at       timestamptz,
  amount_paid   numeric(14,2) not null default 0
);

create table if not exists public.billing_settings (
  id          int primary key default 1 check (id = 1),
  profile     jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);
insert into public.billing_settings (id) values (1) on conflict (id) do nothing;

alter table public.billing_docs     enable row level security;
alter table public.billing_settings enable row level security;

drop policy if exists "admins manage billing docs" on public.billing_docs;
create policy "admins manage billing docs" on public.billing_docs
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admins manage billing settings" on public.billing_settings;
create policy "admins manage billing settings" on public.billing_settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant select, insert, update, delete on public.billing_docs, public.billing_settings to authenticated;
revoke all on public.billing_docs, public.billing_settings from anon;

-- A client opening a share link sees only that one document (and your business details).
create or replace function public.get_shared_doc(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.billing_docs;
begin
  if p_token is null or length(p_token) < 32 then return null; end if;
  select * into d from billing_docs where share_token = p_token;
  if not found then return null; end if;
  if d.status <> 'Draft' and d.viewed_at is null then
    update billing_docs set viewed_at = now() where id = d.id;
  end if;
  return jsonb_build_object(
    'doc', to_jsonb(d) - 'lead_id' - 'source_quote' - 'share_token',
    'business', (select profile from billing_settings where id = 1));
end $$;

-- The client can accept a quotation from the link (only while it is open).
create or replace function public.accept_quote(p_token text, p_name text)
returns text language plpgsql security definer set search_path = public as $$
declare v text;
begin
  update billing_docs
     set status = 'Accepted', accepted_at = now(), accepted_by = left(trim(coalesce(p_name,'')), 100), updated_at = now()
   where share_token = p_token and kind = 'quote' and status in ('Draft','Sent')
     and (due_date is null or due_date >= current_date)
  returning status into v;
  return v;
end $$;

revoke all on function public.get_shared_doc(text) from public;
revoke all on function public.accept_quote(text, text) from public;
grant execute on function public.get_shared_doc(text) to anon, authenticated;
grant execute on function public.accept_quote(text, text) to anon, authenticated;
