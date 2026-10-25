-- Create the public blessings table without losing data from the earlier
-- wedding_blessings schema. Existing rows and their moderation state survive.
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
  is_approved boolean not null default false,
  from_bride_brother boolean not null default false,
  constraint blessings_name_length check (char_length(btrim(name)) between 1 and 80),
  constraint blessings_message_length check (char_length(btrim(message)) between 3 and 800)
);

-- Add the moderation column to existing data and translate the previous text
-- status once, while retaining that column and every existing row.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'blessings'
      and column_name = 'is_approved'
  ) then
    alter table public.blessings
      add column is_approved boolean not null default false;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'blessings'
        and column_name = 'status'
    ) then
      execute 'update public.blessings set is_approved = (status = ''approved'')';
    end if;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'blessings'
      and column_name = 'from_bride_brother'
  ) then
    alter table public.blessings
      add column from_bride_brother boolean not null default false;
  end if;
end
$$;

create index if not exists blessings_approved_created_at_idx
  on public.blessings (created_at desc)
  where is_approved = true;

alter table public.blessings enable row level security;
revoke all on public.blessings from anon, authenticated;
grant select on public.blessings to anon, authenticated;
grant insert (name, message, from_bride_brother)
  on public.blessings to anon, authenticated;

drop policy if exists "Anyone can read approved blessings" on public.blessings;
create policy "Anyone can read approved blessings"
  on public.blessings
  for select
  to anon, authenticated
  using (is_approved = true);

drop policy if exists "Anyone can submit pending blessings" on public.blessings;
create policy "Anyone can submit pending blessings"
  on public.blessings
  for insert
  to anon, authenticated
  with check (
    is_approved = false
    and created_at between now() - interval '1 minute' and now() + interval '1 minute'
  );
