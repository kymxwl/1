-- =============================================================================
-- 20260101000000_foundation.sql
-- Foundation: extensions, roles, and the identity/commerce tables the LMS
-- REUSES rather than owns.
--
-- Governing Principle #1 (One student identity): the LMS does not create a
-- second student table. In the real `tgi-app` these tables already exist as
-- part of auth + intake. They are (re)declared here with `create table if not
-- exists` so this migration set stands up a coherent database in isolation
-- (CI, local dev, review) without clobbering production rows. In production
-- these blocks are no-ops.
-- =============================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "citext";      -- case-insensitive email

-- -----------------------------------------------------------------------------
-- App roles. In Supabase, auth.users holds the credential; role lives here.
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type app_role as enum ('student', 'instructor', 'admin');
  end if;
end$$;

-- profiles: 1:1 with auth.users. `role` drives every RLS policy.
create table if not exists profiles (
  id          uuid primary key,           -- = auth.users.id in production
  role        app_role not null default 'student',
  full_name   text not null,
  email       citext unique,
  created_at  timestamptz not null default now()
);

-- students: the enduring student record. In production this predates the LMS.
create table if not exists students (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references profiles(id),
  first_name   text not null,
  last_name    text not null,
  dob          date,
  phone        text,
  created_at   timestamptz not null default now()
);

-- E-sign enrollment packets (existing system). Referenced by enrollments.
create table if not exists enrollment_agreements (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id),
  signed_at    timestamptz,
  packet_url   text,
  is_complete  boolean not null default false
);

-- Payments / approved non-cash pathways (existing system). Payment LOGIC
-- (calc_refund, Stripe) is out of scope; we only need to know a valid pathway
-- exists to gate enrollment.
create table if not exists payment_records (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references students(id),
  pathway       text not null check (pathway in ('cash','card','financing','va','wioa','scholarship','other_noncash')),
  is_approved   boolean not null default false,
  recorded_at   timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Role helper used throughout RLS. SECURITY DEFINER so it can read profiles
-- regardless of the caller's own RLS.
-- -----------------------------------------------------------------------------
create or replace function current_app_role()
returns app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from profiles where id = auth.uid();
$$;

comment on function current_app_role is
  'Resolves the calling user''s app_role from profiles. Used by RLS policies.';
