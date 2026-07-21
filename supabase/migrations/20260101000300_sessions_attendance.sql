-- =============================================================================
-- 20260101000300_sessions_attendance.sql
-- Section 2.3 Sessions & Attendance -- *TWC critical*.
--
-- Append-only. Corrections are NEW rows that supersede prior rows
-- (Governing Principle #2). UPDATE/DELETE grants are revoked in the RLS
-- migration; supersession is an INSERT with supersedes_id set.
--
-- RESOLVED OPEN DECISIONS (spec §6) are stored per-program in
-- `attendance_policies` so the rule is data, not code (Principle #3, #5).
-- Values below are the documented recommendations; see docs/DECISIONS.md.
-- =============================================================================

-- Per-program attendance policy. Versioned with the program (frozen alongside).
create table if not exists attendance_policies (
  program_id                 uuid primary key references programs(id),
  -- #1 Rounding rule: minutes -> clock hours, rounded DOWN to this granularity.
  rounding_minutes           int not null default 15,      -- nearest quarter hour
  -- #2 Tardy threshold: arriving strictly more than N minutes late is 'tardy'.
  tardy_threshold_minutes    int not null default 10,
  -- Below this many minutes present, the block counts as 'absent' (0 hours).
  absent_floor_minutes       int not null default 1,
  -- #3 Max absences before termination review; makeup restores HOURS but does
  --    NOT decrement the absence count (see docs/DECISIONS.md).
  max_absences               int not null default 3,
  makeup_resets_absence      boolean not null default false,
  updated_at                 timestamptz not null default now()
);

create table if not exists sessions (
  id                     uuid primary key default gen_random_uuid(),
  cohort_id              uuid not null references cohorts(id),
  session_date           date not null,
  start_time             time not null,
  end_time               time not null,
  scheduled_clock_hours  numeric(6,2) not null,
  chapter_ids            uuid[] not null default '{}',
  instructor_id          uuid references profiles(id),
  status                 text not null default 'scheduled'
                           check (status in ('scheduled','held','cancelled','makeup')),
  session_type           text not null default 'lecture'
                           check (session_type in ('lecture','lab','assessment','makeup')),
  -- For makeup sessions, the original missed session whose hours this replaces
  -- (spec §2.3: "a makeup session's hours attach to the original missed session
  -- for reporting").
  makeup_for_session_id  uuid references sessions(id),
  created_at             timestamptz not null default now(),
  check (end_time > start_time)
);

create index if not exists idx_sessions_cohort on sessions(cohort_id, session_date);

-- -----------------------------------------------------------------------------
-- Attendance records: APPEND-ONLY.
-- clock_hours_earned is COMPUTED from minutes_present (Principle #3: no human
-- types the outcome). A BEFORE INSERT trigger derives it from policy.
-- -----------------------------------------------------------------------------
create table if not exists attendance_records (
  id                  uuid primary key default gen_random_uuid(),
  enrollment_id       uuid not null references enrollments(id),
  session_id          uuid not null references sessions(id),
  status              text not null
                        check (status in ('present','absent','tardy','excused','left_early')),
  clock_hours_earned  numeric(6,2) not null default 0,   -- computed, see trigger
  minutes_present     int not null default 0 check (minutes_present >= 0),
  recorded_by         uuid references profiles(id),
  recorded_at         timestamptz not null default now(),
  supersedes_id       uuid references attendance_records(id),
  correction_reason   text,
  -- A correction (supersedes_id set) MUST carry a reason (Principle #2).
  check (supersedes_id is null or correction_reason is not null)
);

create index if not exists idx_attendance_enrollment on attendance_records(enrollment_id);
create index if not exists idx_attendance_session      on attendance_records(session_id);
create index if not exists idx_attendance_supersedes   on attendance_records(supersedes_id);

-- Derive clock_hours_earned + normalize status floor from stored policy.
create or replace function compute_attendance_hours()
returns trigger
language plpgsql
as $$
declare
  pol           attendance_policies%rowtype;
  granularity   int;
begin
  select ap.* into pol
  from attendance_policies ap
  join cohorts co on co.program_id = ap.program_id
  join sessions s on s.cohort_id = co.id
  where s.id = new.session_id;

  granularity := coalesce(pol.rounding_minutes, 15);

  -- 'absent' and 'excused' earn zero hours regardless of minutes.
  if new.status in ('absent','excused') then
    new.clock_hours_earned := 0;
    new.minutes_present := 0;
    return new;
  end if;

  -- Round DOWN to the nearest `granularity` minutes, then convert to hours.
  new.clock_hours_earned :=
    (floor(new.minutes_present::numeric / granularity) * granularity) / 60.0;

  return new;
end;
$$;

drop trigger if exists trg_compute_attendance_hours on attendance_records;
create trigger trg_compute_attendance_hours
  before insert on attendance_records
  for each row execute function compute_attendance_hours();
