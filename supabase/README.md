# Supabase backend

## With the Supabase CLI (recommended)

```bash
supabase start
supabase db reset      # runs migrations/ in order, then seed.sql
```

## Directly with psql (how these were validated)

Supabase provides the `authenticated`/`anon` roles and `auth.uid()` in a real
project. To apply the migrations against a bare Postgres, create shims first:

```sql
create role authenticated;
create role anon;
create schema if not exists auth;
create or replace function auth.uid() returns uuid
  language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
```

Then, in filename order:

```bash
for f in migrations/*.sql; do psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"; done
psql "$DATABASE_URL" -f seed.sql
```

To simulate a signed-in user in psql (for testing RLS):

```sql
set role authenticated;
select set_config('request.jwt.claim.sub', '<profiles.id uuid>', false);
-- ... queries now run as that user under RLS ...
reset role;
```

## Migration order

| File | Contents |
|------|----------|
| `..._foundation.sql` | extensions, `app_role`, reused identity tables, `current_app_role()` |
| `..._curriculum.sql` | programs / courses / chapters / lessons / resources |
| `..._cohorts_enrollment.sql` | cohorts, enrollments, prereq gate, curriculum freeze |
| `..._sessions_attendance.sql` | attendance policy, sessions, append-only attendance + hour trigger |
| `..._assessments.sql` | question bank, assessments, attempts |
| `..._skills.sql` | skills, benchmarks, evaluations + tier trigger |
| `..._completion_certificates.sql` | completion evals, certificate counter + certificates |
| `..._views.sql` | ledger, current tier, answer-key-free question view |
| `..._functions.sql` | the 6 server-side functions |
| `..._rls.sql` | all row-level security policies |
| `..._append_only_guards.sql` | block-mutation triggers + revoked grants |
| `..._grants.sql` | base client-role grants (RLS remains the boundary) |

Regenerate the app's types after a schema change:

```bash
supabase gen types typescript --local > ../src/types/supabase.ts
```
