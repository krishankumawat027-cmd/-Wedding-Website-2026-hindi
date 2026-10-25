# Blessings database setup

The connected Supabase project is the project whose API URL is set in `.env.local` (`qijexowdwmixpcohrhgf.supabase.co`). The website uses the `public.blessings` table.

## Apply migrations

For a fresh project, run the migration files in timestamp order from `migrations/` in that project's SQL Editor. For an existing `public.blessings` table, apply any missing forward migrations in timestamp order. `20261027000000_auto_approve_blessings.sql` keeps RLS enabled, approves submissions automatically, and sets the default so public inserts appear immediately. `20261028000000_remove_confirmed_blessing_duplicates.sql` removes only the two duplicate IDs confirmed during inspection, if their name and message still match the retained earliest row.

New submissions write only `name` and `message`; the database sets `is_approved = true`. Public reads are limited to approved rows. The legacy `from_bride_brother` column may remain in the table, but the site no longer displays or writes a relationship label. Never put a service-role key in frontend code or a `VITE_*` variable.

For local development, `.env.local` must contain `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. Configure the same public values in deployment settings before building and deploying.