create table if not exists public.wedding_blessings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  message text not null,
  from_bride_brother boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  constraint wedding_blessings_name_length
    check (char_length(btrim(name)) between 1 and 80),
  constraint wedding_blessings_message_length
    check (char_length(btrim(message)) between 3 and 800)
);

create index if not exists wedding_blessings_approved_created_at_idx
  on public.wedding_blessings (created_at desc)
  where status = 'approved';

alter table public.wedding_blessings enable row level security;

revoke all on public.wedding_blessings from anon, authenticated;
grant select on public.wedding_blessings to anon, authenticated;
grant insert (name, message, from_bride_brother)
  on public.wedding_blessings to anon, authenticated;

drop policy if exists "Anyone can read approved blessings" on public.wedding_blessings;
create policy "Anyone can read approved blessings"
  on public.wedding_blessings
  for select
  to anon, authenticated
  using (status = 'approved');

drop policy if exists "Anyone can submit pending blessings" on public.wedding_blessings;
create policy "Anyone can submit pending blessings"
  on public.wedding_blessings
  for insert
  to anon, authenticated
  with check (
    status = 'pending'
    and created_at between now() - interval '1 minute' and now() + interval '1 minute'
  );
