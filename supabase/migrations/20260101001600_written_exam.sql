-- =============================================================================
-- 20260101001600_written_exam.sql
-- Manual grading for instructor-scored written exams (Appendix L).
--
-- Appendix L questions are short-answer/essay with no machine answer key
-- (correct_answer = 'null'::jsonb). They cannot be auto-graded, so:
--   * grade_attempt() REFUSES any assessment containing a manual-graded
--     question (directing the caller to grade_written_attempt), and
--   * grade_written_attempt() takes the proctor's per-question marks and
--     COMPUTES the score. Zero discretion is preserved: the proctor records
--     per-question marks (what happened); the total is computed, never typed.
-- =============================================================================

-- Guard grade_attempt: refuse manual-graded assessments.
create or replace function grade_attempt(p_attempt_id uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  att        assessment_attempts%rowtype;
  asmt       assessments%rowtype;
  q          record;
  total      int := 0;
  correct    int := 0;
  pct        numeric(5,2);
  given      jsonb;
  key        jsonb;
begin
  select * into att from assessment_attempts where id = p_attempt_id;
  if not found then
    raise exception 'grade_attempt: attempt % not found', p_attempt_id;
  end if;
  if att.void then
    raise exception 'grade_attempt: attempt % is void and cannot be graded', p_attempt_id;
  end if;

  select * into asmt from assessments where id = att.assessment_id;

  if asmt.is_secure and att.proctored_by is null then
    raise exception 'grade_attempt: secure assessment requires proctored_by';
  end if;

  -- Manual-graded assessments (any question without a machine key) must go
  -- through grade_written_attempt().
  if exists (
    select 1 from assessment_questions aq
    join question_bank qb on qb.id = aq.question_id
    where aq.assessment_id = att.assessment_id
      and qb.correct_answer = 'null'::jsonb
  ) then
    raise exception 'grade_attempt: assessment % is instructor-graded; use grade_written_attempt()', att.assessment_id;
  end if;

  for q in
    select qb.id, qb.type, qb.correct_answer
    from assessment_questions aq
    join question_bank qb on qb.id = aq.question_id
    where aq.assessment_id = att.assessment_id
  loop
    total := total + 1;
    given := att.responses -> q.id::text;
    key   := q.correct_answer;
    if given is not null then
      if q.type = 'short_answer' then
        if lower(btrim(given #>> '{}')) = any (
             select lower(btrim(v)) from jsonb_array_elements_text(
               case when jsonb_typeof(key) = 'array' then key else jsonb_build_array(key #>> '{}') end
             ) as t(v)
           )
        then correct := correct + 1; end if;
      else
        if given = key then correct := correct + 1; end if;
      end if;
    end if;
  end loop;

  if total = 0 then
    raise exception 'grade_attempt: assessment % has no mapped questions', att.assessment_id;
  end if;

  pct := round((correct::numeric / total) * 100, 2);
  update assessment_attempts
     set score = pct, passed = (pct >= asmt.passing_score), submitted_at = coalesce(submitted_at, now())
   where id = p_attempt_id;
  return pct;
end;
$$;

-- -----------------------------------------------------------------------------
-- grade_written_attempt(attempt_id, marks) -> numeric (score %)
-- marks: { "<question_id>": <0..1> }. Each mapped question is worth one point;
-- unmarked questions score 0. score = round(sum(points)/question_count*100, 2).
-- Callable by the proctor on the attempt, the enrollment's instructor, or admin.
-- -----------------------------------------------------------------------------
create or replace function grade_written_attempt(p_attempt_id uuid, p_marks jsonb)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  att      assessment_attempts%rowtype;
  asmt     assessments%rowtype;
  total    int := 0;
  awarded  numeric := 0;
  pct      numeric(5,2);
  q        record;
begin
  select * into att from assessment_attempts where id = p_attempt_id;
  if not found then
    raise exception 'grade_written_attempt: attempt % not found', p_attempt_id;
  end if;
  if att.void then
    raise exception 'grade_written_attempt: attempt % is void', p_attempt_id;
  end if;

  select * into asmt from assessments where id = att.assessment_id;
  if asmt.is_secure and att.proctored_by is null then
    raise exception 'grade_written_attempt: secure assessment requires proctored_by';
  end if;

  if not (
    current_app_role() = 'admin'
    or instructs_enrollment(att.enrollment_id)
    or att.proctored_by = auth.uid()
  ) then
    raise exception 'grade_written_attempt: only the proctor, the cohort instructor, or an admin may grade';
  end if;

  for q in
    select aq.question_id from assessment_questions aq where aq.assessment_id = att.assessment_id
  loop
    total := total + 1;
    awarded := awarded + least(greatest(coalesce((p_marks ->> q.question_id::text)::numeric, 0), 0), 1);
  end loop;

  if total = 0 then
    raise exception 'grade_written_attempt: assessment % has no mapped questions', att.assessment_id;
  end if;

  pct := round((awarded / total) * 100, 2);
  update assessment_attempts
     set score = pct, passed = (pct >= asmt.passing_score), submitted_at = coalesce(submitted_at, now())
   where id = p_attempt_id;
  return pct;
end;
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function grade_written_attempt(uuid, jsonb) to authenticated;
  end if;
end$$;
