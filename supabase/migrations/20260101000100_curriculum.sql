-- =============================================================================
-- 20260101000100_curriculum.sql
-- Section 2.1 Curriculum: program -> course -> chapter -> lesson, plus resources.
--
-- Versioning note (spec §2.1): curriculum is versioned at the `programs` level.
-- A cohort pins to one program_id at creation and never migrates. Editing a
-- chapter after graduation must NOT alter what a past cohort was taught -- so
-- curriculum edits should be published as a NEW program version, not an
-- in-place mutation of a program a completed cohort points at. Enforced by
-- convention + the `is_active` / `effective_date` fields; a hard freeze trigger
-- is added once cohorts exist (see 20260101000200).
-- =============================================================================

create table if not exists programs (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  version            text not null,                 -- e.g. "2026.1"
  total_clock_hours  numeric(6,2) not null default 100,
  is_active          boolean not null default true,
  effective_date     date not null default current_date,
  created_at         timestamptz not null default now(),
  unique (name, version)
);

create table if not exists courses (
  id           uuid primary key default gen_random_uuid(),
  program_id   uuid not null references programs(id),
  name         text not null,
  sequence     int not null,
  clock_hours  numeric(6,2) not null default 0,
  unique (program_id, sequence)
);

-- Maps to the 25 manual chapters.
create table if not exists chapters (
  id               uuid primary key default gen_random_uuid(),
  course_id        uuid not null references courses(id),
  number           int not null,                    -- 1..25
  title            text not null,
  sequence         int not null,
  clock_hours      numeric(6,2) not null default 0,
  manual_page_ref  text,
  unique (course_id, number)
);

create table if not exists lessons (
  id                  uuid primary key default gen_random_uuid(),
  chapter_id          uuid not null references chapters(id),
  title               text not null,
  sequence            int not null,
  objectives          jsonb not null default '[]'::jsonb,
  lecture_deck_url    text,
  instructor_notes_url text,
  estimated_minutes   int not null default 0,
  unique (chapter_id, sequence)
);

-- Flash card sets, handouts, video links, deck files.
create table if not exists resources (
  id          uuid primary key default gen_random_uuid(),
  owner_type  text not null check (owner_type in ('program','course','chapter','lesson')),
  owner_id    uuid not null,
  kind        text not null check (kind in ('deck','flashcards','video','handout','manual')),
  title       text not null,
  url         text not null,
  visibility  text not null default 'student' check (visibility in ('student','instructor','admin')),
  created_at  timestamptz not null default now()
);

create index if not exists idx_courses_program   on courses(program_id);
create index if not exists idx_chapters_course    on chapters(course_id);
create index if not exists idx_lessons_chapter    on lessons(chapter_id);
create index if not exists idx_resources_owner     on resources(owner_type, owner_id);
