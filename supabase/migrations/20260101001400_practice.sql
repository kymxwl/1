-- =============================================================================
-- 20260101001400_practice.sql
-- M4 — Quizzes & Flash Cards.
--
-- Two pieces:
--   1. `flashcards` — study content (front/back), DELIBERATELY SEPARATE from
--      question_bank so that revealing a flash card can never leak a secure
--      exam's answer key (Principle #4). Flash cards are a study aid; their
--      backs are meant to be seen.
--   2. `attempt_feedback()` — post-submission feedback with explanations for
--      NON-SECURE practice quizzes only. The answer key is revealed AFTER the
--      student has answered and only for non-secure assessments; secure exams
--      never return it.
-- =============================================================================

create table if not exists flashcards (
  id          uuid primary key default gen_random_uuid(),
  chapter_id  uuid not null references chapters(id),
  front       text not null,
  back        text not null,
  sequence    int not null default 0,
  is_active   boolean not null default true
);

create index if not exists idx_flashcards_chapter on flashcards(chapter_id);

alter table flashcards enable row level security;

create policy flashcards_read on flashcards for select using (is_active or current_app_role() = 'admin');
create policy flashcards_admin on flashcards for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on flashcards to authenticated;
    grant insert, update, delete on flashcards to authenticated; -- admin via RLS
  end if;
end$$;

-- -----------------------------------------------------------------------------
-- attempt_feedback(attempt_id) -> jsonb
-- Per-question feedback for a submitted, NON-SECURE attempt owned by the caller
-- (or their instructor / an admin). Reveals correct_answer + explanation only
-- here, only after submission, only for non-secure assessments.
-- -----------------------------------------------------------------------------
create or replace function attempt_feedback(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  att   assessment_attempts%rowtype;
  asmt  assessments%rowtype;
  out   jsonb;
begin
  select * into att from assessment_attempts where id = p_attempt_id;
  if not found then
    raise exception 'attempt_feedback: attempt % not found', p_attempt_id;
  end if;

  select * into asmt from assessments where id = att.assessment_id;
  if asmt.is_secure then
    raise exception 'attempt_feedback: feedback is not available for secure assessments';
  end if;
  if att.submitted_at is null then
    raise exception 'attempt_feedback: attempt not yet submitted';
  end if;

  if not (
    owns_enrollment(att.enrollment_id)
    or instructs_enrollment(att.enrollment_id)
    or current_app_role() = 'admin'
  ) then
    raise exception 'attempt_feedback: not authorized';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', qb.id,
      'stem', qb.stem,
      'type', qb.type,
      'options', qb.options,
      'given', att.responses -> qb.id::text,
      'correct_answer', qb.correct_answer,
      'explanation', qb.explanation,
      'is_correct', case
        when qb.type = 'short_answer' then
          lower(btrim(coalesce(att.responses ->> qb.id::text, ''))) = any (
            select lower(btrim(v)) from jsonb_array_elements_text(
              case when jsonb_typeof(qb.correct_answer) = 'array'
                   then qb.correct_answer
                   else jsonb_build_array(qb.correct_answer #>> '{}') end
            ) as t(v)
          )
        else (att.responses -> qb.id::text) = qb.correct_answer
      end
    ) order by aq.sequence
  ) into out
  from assessment_questions aq
  join question_bank qb on qb.id = aq.question_id
  where aq.assessment_id = att.assessment_id;

  return coalesce(out, '[]'::jsonb);
end;
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function attempt_feedback(uuid) to authenticated;
  end if;
end$$;
