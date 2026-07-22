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

**Frontend — Expo app (typechecks cleanly):**
- Typed Supabase data layer + one service module per module (M1–M9)
- Student screens: Sign-in, Dealer Passport (M7), Course Outline (M1),
  Practice — flash cards & quizzes with post-submission feedback (M4)
- Staff console: Cohorts & scheduling (M2), Take Attendance w/ offline queue
  (M3), Score a Skill (M6), Proctor a Secure Exam (M5), Reporting — registers &
  rosters (M9), Completion & Certificate — one-button issue (M8)
- Certificate PDFs are rendered by the `issue-certificate` **edge function**
  (`supabase/functions/`): it computes eligibility, issues the gapless number,
  renders the PDF (`pdf-lib`), and stores it in a private `certificates` bucket
  served via signed URLs

**CI (`.github/workflows/ci.yml`):**
- `typecheck` job: `npm ci` + `tsc --noEmit`
- `database` job: spins up Postgres, applies all migrations + seed, runs
  `.github/ci/smoke.sql` (ledger math, computed tier, answer-key isolation,
  proctor enforcement, append-only block, session-calendar generation)

See [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) for the model and
[`docs/DECISIONS.md`](docs/DECISIONS.md) for the resolved Open Decisions (§6).
To stand up a real Supabase project see [`DEPLOY.md`](DEPLOY.md); for the full
path to production see [`docs/COMPLETION.md`](docs/COMPLETION.md).

## Repository layout

```
supabase/
  migrations/       16 ordered SQL migrations (schema → functions → RLS → guards → storage → auth)
  functions/        issue-certificate edge function (M8)
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
enrollment.

All nine build-order modules (M1–M9) now have a working UI or console backed by
the server-side rules.
