-- Publish all blessings automatically while keeping RLS enabled. Adopt the
-- former table name if the earlier rename migration has not been run yet.
do $$
begin
  if to_regclass('public.blessings') is null
     and to_regclass('public.wedding_blessings') is not null then
    alter table public.wedding_blessings rename to blessings;
  end if;
end
$$;

create table if not exists public.blessings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  message text not null,
  created_at timestamptz not null default now(),
  is_approved boolean not null default true,
  from_bride_brother boolean not null default false,
  constraint blessings_name_length check (char_length(btrim(name)) between 1 and 80),
  constraint blessings_message_length check (char_length(btrim(message)) between 3 and 800)
);

alter table public.blessings
  add column if not exists is_approved boolean not null default true;
alter table public.blessings
  add column if not exists from_bride_brother boolean not null default false;
alter table public.blessings alter column is_approved set default true;

-- No submissions remain stuck in a pending state after this migration.
update public.blessings set is_approved = true where is_approved = false;

create index if not exists blessings_approved_created_at_idx
  on public.blessings (created_at desc)
  where is_approved = true;

alter table public.blessings enable row level security;
revoke all on public.blessings from anon, authenticated;
grant select on public.blessings to anon, authenticated;
grant insert (name, message)
  on public.blessings to anon, authenticated;

drop policy if exists "Anyone can read approved blessings" on public.blessings;
create policy "Anyone can read approved blessings"
  on public.blessings
  for select
  to anon, authenticated
  using (is_approved = true);

drop policy if exists "Anyone can submit pending blessings" on public.blessings;
drop policy if exists "Anyone can submit blessings" on public.blessings;
create policy "Anyone can submit blessings"
  on public.blessings
  for insert
  to anon, authenticated
  with check (
    is_approved = true
    and created_at between now() - interval '1 minute' and now() + interval '1 minute'
  );
