-- =============================================================================
-- 20260101000200_cohorts_enrollment.sql
-- Section 2.2 Cohorts & Enrollment.
--
-- Enforcement (spec §2.2): enrollment cannot be created unless the student has
-- a COMPLETED e-sign packet AND an approved payment / non-cash pathway. This is
-- enforced in a DB trigger, not the app (Governing Principle: keep the rule
-- where it cannot be bypassed).
-- =============================================================================

create table if not exists cohorts (
  id             uuid primary key default gen_random_uuid(),
  program_id     uuid not null references programs(id),
  name           text not null,                      -- e.g. "2026-A"
  start_date     date not null,
  end_date       date not null,
  instructor_id  uuid references profiles(id),
  capacity       int not null default 24,
  status         text not null default 'planned'
                   check (status in ('planned','active','completed','cancelled')),
  location       text,
  created_at     timestamptz not null default now(),
  unique (program_id, name),
  check (end_date >= start_date)
);

create table if not exists enrollments (
  id                       uuid primary key default gen_random_uuid(),
  student_id               uuid not null references students(id),
  cohort_id                uuid not null references cohorts(id),
  enrolled_at              timestamptz not null default now(),
  status                   text not null default 'enrolled'
                             check (status in ('enrolled','active','withdrawn','completed','terminated')),
  status_reason            text,
  tuition_rate             text not null default 'standard'
                             check (tuition_rate in ('standard','industry')),
  enrollment_agreement_id  uuid references enrollment_agreements(id),
  unique (student_id, cohort_id)
);

create index if not exists idx_enrollments_cohort  on enrollments(cohort_id);
create index if not exists idx_enrollments_student on enrollments(student_id);

-- -----------------------------------------------------------------------------
-- Gate: no enrollment without a complete packet + approved payment pathway.
-- -----------------------------------------------------------------------------
create or replace function assert_enrollment_prereqs()
returns trigger
language plpgsql
as $$
declare
  has_packet   boolean;
  has_payment  boolean;
begin
  select exists (
    select 1 from enrollment_agreements ea
    where ea.id = new.enrollment_agreement_id
      and ea.student_id = new.student_id
      and ea.is_complete
  ) into has_packet;

  if not has_packet then
    raise exception 'Enrollment blocked: student % has no completed e-sign packet', new.student_id
      using errcode = 'check_violation';
  end if;

  select exists (
    select 1 from payment_records pr
    where pr.student_id = new.student_id
      and pr.is_approved
  ) into has_payment;

  if not has_payment then
    raise exception 'Enrollment blocked: student % has no approved payment / non-cash pathway', new.student_id
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enrollment_prereqs on enrollments;
create trigger trg_enrollment_prereqs
  before insert on enrollments
  for each row execute function assert_enrollment_prereqs();

-- -----------------------------------------------------------------------------
-- Curriculum freeze: once any cohort references a program, the program's
-- structural rows must not change (§2.1 versioning note, §7). New curriculum =
-- new program version.
-- -----------------------------------------------------------------------------
create or replace function assert_program_not_frozen()
returns trigger
language plpgsql
as $$
declare
  pid uuid;
begin
  -- Resolve the affected program id for the table this trigger fired on.
  if tg_table_name = 'programs' then
    pid := coalesce(new.id, old.id);
  elsif tg_table_name = 'courses' then
    pid := coalesce(new.program_id, old.program_id);
  elsif tg_table_name = 'chapters' then
    select c.program_id into pid from courses c where c.id = coalesce(new.course_id, old.course_id);
  elsif tg_table_name = 'lessons' then
    select c.program_id into pid
    from chapters ch join courses c on c.id = ch.course_id
    where ch.id = coalesce(new.chapter_id, old.chapter_id);
  end if;

  if exists (select 1 from cohorts where program_id = pid) then
    raise exception
      'Program % is frozen: a cohort is pinned to it. Publish a new program version instead of editing curriculum in place.', pid
      using errcode = 'check_violation';
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_freeze_programs on programs;
create trigger trg_freeze_programs
  after update or delete on programs
  for each row execute function assert_program_not_frozen();

drop trigger if exists trg_freeze_courses on courses;
create trigger trg_freeze_courses
  after update or delete on courses
  for each row execute function assert_program_not_frozen();

drop trigger if exists trg_freeze_chapters on chapters;
create trigger trg_freeze_chapters
  after update or delete on chapters
  for each row execute function assert_program_not_frozen();

drop trigger if exists trg_freeze_lessons on lessons;
create trigger trg_freeze_lessons
  after update or delete on lessons
  for each row execute function assert_program_not_frozen();
