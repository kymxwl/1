# TGI Learning Management System

Learning management system for the **Texas Gaming Institute** — a 100-clock-hour
Professional Poker Dealer program. React Native / Expo (SDK 54) front end,
Supabase (Postgres + RLS) back end.

Built to the [`TGILMSSPEC`](docs/) data-model & module spec. The design is driven
by five governing principles: **one student identity**, **append-only
regulatory records**, **zero discretion at decision points**, **answer keys
never reach the client**, and **clock hours as the regulatory unit**.

> This repository was stood up greenfield (the target `tgi-app` schema did not
> yet exist here), so it includes minimal stand-ins for the "already exists"
> identity/commerce tables (`profiles`, `students`, `enrollment_agreements`,
> `payment_records`) declared with `create table if not exists` — in production
> these are no-ops that defer to the real rows.

## What's implemented

**Backend — the regulatory core (complete & validated):**
- Full schema: 24 tables, 4 views, 6 server-side functions, 38 RLS policies
- Append-only enforcement (revoked grants + block triggers) on the four
  TWC-inspectable record types
- Computed, zero-discretion outcomes: clock hours, skill tiers, pass/fail,
  completion outcome, gapless certificate numbers
- Answer keys isolated behind `question_bank_public`; grading is server-side only
- Seed data: the program, 25 chapters, lessons, skills+benchmarks, assessments,
  a cohort with sessions and sample attendance/skill data

**Frontend — Expo app (typechecks cleanly, representative screens):**
- Typed Supabase data layer + one service module per module (M1–M8)
- Screens: Sign-in, Dealer Passport (M7), Course Outline (M1),
  Take Attendance with offline queue (M3)
- Instructor/admin consoles are stubbed where they mount

See [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) for the model and
[`docs/DECISIONS.md`](docs/DECISIONS.md) for the resolved Open Decisions (§6).

## Repository layout

```
supabase/
  migrations/       11 ordered SQL migrations (schema → functions → RLS → guards)
  seed.sql          demo data (safe on `supabase db reset`)
  config.toml       local Supabase config
src/
  lib/supabase.ts   typed client
  types/database.ts hand-authored schema types (or: npm run db:types)
  services/         curriculum, attendance, offlineQueue, assessments, skills,
                    completion, session
  screens/          SignIn, Passport, CourseOutline, TakeAttendance
  theme.ts
App.tsx             auth gate + tab navigation
docs/
```

## Running the backend

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker.

```bash
supabase start          # boots local Postgres + Studio
supabase db reset       # applies migrations/*.sql then seed.sql
```

The migrations also apply directly with `psql` in filename order against any
Postgres 14+ (create roles `authenticated`, `anon` and an `auth.uid()` shim
first — see `supabase/README.md`). This is exactly how they were validated here.

## Running the app

```bash
cp .env.example .env    # fill in your Supabase URL + anon key
npm install --legacy-peer-deps
npm run typecheck       # tsc --noEmit  (passes clean)
npm start               # expo start
```

Sign in with a seeded user (e.g. `sam@tgi.test`) once you've created the
corresponding Supabase Auth user with a matching `profiles.id`.

## Verification performed

- All 11 migrations + seed apply cleanly against Postgres from a fresh schema.
- Ledger math verified: 200 min tardy → 3.25 hr (round-down to quarter hour).
- Skill tier verified: 13 s shuffle → **gold** (computed, not entered).
- `grade_attempt` verified: 3/3 → 100, `passed=true`; short-answer matched
  case-insensitively; **secure exam without a proctor is rejected**.
- Append-only verified: UPDATE on `attendance_records` is blocked; corrections
  flow through `record_attendance_correction()` as superseding rows.
- Gapless numbering verified: `TGI-000001`, `TGI-000002`; non-eligible outcomes
  are rejected by `issue_certificate()`.
- RLS verified as a student: sees only own attendance/enrollment; `question_bank`
  returns 0 rows while `question_bank_public` returns questions.
- Curriculum freeze verified: editing a chapter after a cohort pins the program
  is rejected.
- App typechecks with **0 errors** (`tsc --noEmit`, strict).

## Not in scope (v1, per spec §1)

Forums/messaging, video hosting, payment/refund logic, public self-serve
enrollment. Modules M5 (secure-exam delivery UI), M6 (rubric capture UI), and M9
(admin reporting UI) have their **data + service layers** in place; their
screens are the next build increment.
