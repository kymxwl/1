-- =============================================================================
-- 20260101001500_auth_integration.sql
-- Wires the LMS identity to Supabase Auth so real logins work.
--
-- The contract (relied on by every RLS policy): profiles.id == auth.users.id.
-- Two pieces:
--   1. handle_new_user() — on signup, auto-creates a profiles row (role
--      'student' by default) so a freshly signed-up user immediately has an
--      identity RLS can resolve.
--   2. set_user_role() — admin-only elevation to 'instructor' / 'admin'.
--
-- The signup trigger lives on auth.users, which exists only on a real Supabase
-- project — so it is created inside a guard and simply skipped on bare Postgres
-- (CI), where there is no auth schema. set_user_role() is always created.
--
-- FIRST ADMIN (bootstrap): the trigger makes everyone a student; there is no
-- admin to call set_user_role() yet. Seed the first admin once, out-of-band,
-- with the service role — see DEPLOY.md.
-- =============================================================================

-- Auto-provision a profile when a user signs up.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, role, full_name, email)
  values (
    new.id,
    'student',
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

do $$
begin
  if to_regclass('auth.users') is not null then
    execute 'drop trigger if exists on_auth_user_created on auth.users';
    execute $t$
      create trigger on_auth_user_created
        after insert on auth.users
        for each row execute function handle_new_user()
    $t$;
  else
    raise notice 'auth.users absent (bare Postgres) — skipping signup trigger';
  end if;
end$$;

-- Admin-only role assignment. The only sanctioned way to grant instructor/admin.
create or replace function set_user_role(p_user_id uuid, p_role app_role)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_app_role() <> 'admin' then
    raise exception 'set_user_role: admin role required'
      using errcode = 'insufficient_privilege';
  end if;

  update profiles set role = p_role where id = p_user_id;
  if not found then
    raise exception 'set_user_role: no profile for %', p_user_id;
  end if;
end;
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function set_user_role(uuid, app_role) to authenticated;
  end if;
end$$;
