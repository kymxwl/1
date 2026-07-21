-- =============================================================================
-- 20260101000400_assessments.sql
-- Section 2.4 Assessments.
--
-- Governing Principle #4: answer keys never reach the client. correct_answer
-- and explanation live in question_bank but are unreachable from any client
-- query -- clients read `question_bank_public` (see views migration) and RLS
-- denies direct SELECT on question_bank to student/instructor.
--
-- assessment_attempts is APPEND-ONLY. score/passed are written ONLY by the
-- server-side grade_attempt() function (Principle #3).
-- =============================================================================

create table if not exists question_bank (
  id             uuid primary key default gen_random_uuid(),
  program_id     uuid not null references programs(id),
  chapter_id     uuid references chapters(id),
  stem           text not null,
  type           text not null check (type in ('multiple_choice','true_false','short_answer')),
  options        jsonb not null default '[]'::jsonb,     -- e.g. [{"key":"a","text":"..."}]
  correct_answer jsonb not null,                          -- NEVER sent to clients
  explanation    text,                                    -- NEVER sent to clients
  difficulty     text check (difficulty in ('easy','medium','hard')),
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

create index if not exists idx_question_bank_chapter on question_bank(chapter_id);
create index if not exists idx_question_bank_program on question_bank(program_id);

create table if not exists assessments (
  id                uuid primary key default gen_random_uuid(),
  program_id        uuid not null references programs(id),
  kind              text not null check (kind in ('chapter_quiz','practice','final_exam')),
  form_code         text check (form_code in ('A','B')),    -- A = Appendix L, B = secure Form B
  title             text not null,
  question_count    int not null,
  passing_score     numeric(5,2) not null default 70,
  time_limit_minutes int,
  is_secure         boolean not null default false,
  max_attempts      int not null default 3,
  randomize_order   boolean not null default true,
  created_at        timestamptz not null default now()
);

-- Fixed question mapping for secure exams. Practice quizzes may draw dynamically
-- and can leave this empty.
create table if not exists assessment_questions (
  assessment_id  uuid not null references assessments(id),
  question_id    uuid not null references question_bank(id),
  sequence       int not null,
  primary key (assessment_id, question_id),
  unique (assessment_id, sequence)
);

create table if not exists assessment_attempts (
  id              uuid primary key default gen_random_uuid(),
  enrollment_id   uuid not null references enrollments(id),
  assessment_id   uuid not null references assessments(id),
  attempt_number  int not null,
  started_at      timestamptz not null default now(),
  submitted_at    timestamptz,
  score           numeric(5,2),           -- written only by grade_attempt()
  passed          boolean,                -- written only by grade_attempt()
  proctored_by    uuid references profiles(id),
  responses       jsonb not null default '{}'::jsonb,   -- {question_id: answer}
  void            boolean not null default false,
  void_reason     text,
  unique (enrollment_id, assessment_id, attempt_number)
);

create index if not exists idx_attempts_enrollment on assessment_attempts(enrollment_id);
create index if not exists idx_attempts_assessment on assessment_attempts(assessment_id);
