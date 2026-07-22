# Deploying the TGI LMS

From an empty Supabase project to a working backend the app can log into. Steps
run once per environment (staging, production). Assumes the Supabase CLI is
installed and you are logged in (`supabase login`).

## 1. Create and link the project

```bash
# Create the project in the Supabase dashboard, then link this repo to it:
supabase link --project-ref <YOUR_PROJECT_REF>
```

## 2. Apply the schema

```bash
supabase db push          # applies supabase/migrations/* in order
```

This creates all tables, views, functions, RLS policies, the append-only
guards, and the auth-integration trigger. The `certificates` storage bucket is
created by `20260101001200_storage.sql` (it runs on a real project because the
`storage` schema exists).

> **Seed data is for demos only.** Do **not** run `supabase/seed.sql` against
> production — it inserts fake profiles/students. Load real content instead
> (Phase 3 tooling), or seed a staging project freely.

## 3. Deploy the certificate edge function

```bash
supabase functions deploy issue-certificate
```

The function reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the
Supabase-managed environment — no extra secrets needed for the default setup.
If you add custom secrets later: `supabase secrets set KEY=value`.

## 4. Bootstrap the first admin

Signup auto-creates a `profiles` row with role `student` (the
`handle_new_user` trigger). The first admin has to be set out-of-band, because
`set_user_role()` itself requires an existing admin. After your first user
signs up, in the SQL editor (service role):

```sql
update public.profiles set role = 'admin' where email = 'you@tgi.edu';
```

From then on, that admin assigns every other role in-app (or via
`select set_user_role('<user-uuid>', 'instructor');`).

## 5. Point the app at the project

```bash
cp .env.example .env
# EXPO_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
# EXPO_PUBLIC_SUPABASE_ANON_KEY=<anon key from dashboard → API>
npm install --legacy-peer-deps
npm run typecheck
npm start            # Expo Go, or an EAS build (see Phase 5 in docs/COMPLETION.md)
```

## 6. Smoke-test the live project

Run the same assertions CI runs, against the linked database:

```bash
# From a psql connected to the project (service role), after loading a
# throwaway staging seed:
psql "$DATABASE_URL" -f .github/ci/smoke.sql
```

Then verify end to end in the app: sign up → confirm a `profiles` row appears →
promote yourself to admin → create a cohort → generate its calendar → issue a
certificate and confirm the PDF opens via its signed URL.

---

## Production hardening (recommended)

Once real auth is in place and you are **not** using the demo seed, tie the
profile identity to auth for referential integrity:

```sql
alter table public.profiles
  add constraint profiles_id_fkey
  foreign key (id) references auth.users(id) on delete cascade;
```

(Left out of the default migrations so the demo seed — which inserts standalone
profiles — keeps working locally and in CI.)

See `docs/COMPLETION.md` for the full path to production, including the items
that need the institute and TWC rather than code.
