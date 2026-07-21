-- =============================================================================
-- 20260101000800_functions.sql
-- Section 5 Server-Side Functions. All SECURITY DEFINER; all grading and
-- outcome computation happens here, never on the client (Principles #3, #4).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- clock_hours_for(enrollment_id) -> numeric
-- Canonical hour total. Every report calls this; nothing recomputes locally.
-- -----------------------------------------------------------------------------
create or replace function clock_hours_for(p_enrollment_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(clock_hours_earned, 0)
  from clock_hour_ledger
  where enrollment_id = p_enrollment_id;
$$;

-- -----------------------------------------------------------------------------
-- grade_attempt(attempt_id) -> numeric (the score)
-- Sole writer of assessment_attempts.score / .passed. Compares stored responses
-- to question_bank.correct_answer server-side. Secure exams require a proctor.
-- -----------------------------------------------------------------------------
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

  -- Secure exams are invalid without a proctor (spec §2.4).
  if asmt.is_secure and att.proctored_by is null then
    raise exception 'grade_attempt: secure assessment requires proctored_by';
  end if;

  -- Grade against the assessment's fixed question set. (For dynamic practice
  -- quizzes, the responses object carries the served question ids.)
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
        -- case-insensitive, trimmed exact match against any accepted answer
        if lower(btrim(given #>> '{}')) = any (
             select lower(btrim(v)) from jsonb_array_elements_text(
               case when jsonb_typeof(key) = 'array' then key else jsonb_build_array(key #>> '{}') end
             ) as t(v)
           )
        then
          correct := correct + 1;
        end if;
      else
        -- multiple_choice / true_false: exact jsonb equality
        if given = key then
          correct := correct + 1;
        end if;
      end if;
    end if;
  end loop;

  if total = 0 then
    raise exception 'grade_attempt: assessment % has no mapped questions', att.assessment_id;
  end if;

  pct := round((correct::numeric / total) * 100, 2);

  update assessment_attempts
     set score = pct,
         passed = (pct >= asmt.passing_score),
         submitted_at = coalesce(submitted_at, now())
   where id = p_attempt_id;

  return pct;
end;
$$;

-- -----------------------------------------------------------------------------
-- record_attendance_correction(...) -> uuid (the new superseding row)
-- Inserts a superseding attendance row with reason + actor. The only sanctioned
-- way to "change" attendance (Principle #2 -- corrections are new rows).
-- -----------------------------------------------------------------------------
create or replace function record_attendance_correction(
  p_original_id     uuid,
  p_status          text,
  p_minutes_present int,
  p_recorded_by     uuid,
  p_reason          text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  o      attendance_records%rowtype;
  new_id uuid;
begin
  select * into o from attendance_records where id = p_original_id;
  if not found then
    raise exception 'record_attendance_correction: original % not found', p_original_id;
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'record_attendance_correction: a reason is required';
  end if;

  insert into attendance_records (
    enrollment_id, session_id, status, minutes_present,
    recorded_by, supersedes_id, correction_reason
  ) values (
    o.enrollment_id, o.session_id, p_status, coalesce(p_minutes_present, 0),
    p_recorded_by, p_original_id, p_reason
  )
  returning id into new_id;

  return new_id;   -- clock_hours_earned computed by BEFORE INSERT trigger
end;
$$;

-- -----------------------------------------------------------------------------
-- evaluate_completion(enrollment_id) -> uuid (the completion_evaluations row)
-- Produces the computed snapshot + outcome. No human types the outcome.
-- -----------------------------------------------------------------------------
create or replace function evaluate_completion(p_enrollment_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  led            clock_hour_ledger%rowtype;
  prog           programs%rowtype;
  total_sessions int;
  hours          numeric(6,2);
  att_pct        numeric(5,2);
  best_final     numeric(5,2);
  final_passed   boolean;
  skills_total   int;
  skills_gold    int;
  skills_tiered  int;
  all_gold       boolean;
  all_tiered     boolean;
  perfect        boolean;
  outcome        text;
  snap           jsonb;
  eval_id        uuid;
begin
  select * into led from clock_hour_ledger where enrollment_id = p_enrollment_id;

  select p.* into prog
  from programs p
  join cohorts c on c.program_id = p.id
  join enrollments e on e.cohort_id = c.id
  where e.id = p_enrollment_id;

  hours := coalesce(led.clock_hours_earned, 0);

  -- Attendance % against scheduled clock hours for the cohort.
  select coalesce(sum(s.scheduled_clock_hours), 0) into total_sessions
  from sessions s
  join enrollments e on e.cohort_id = s.cohort_id
  where e.id = p_enrollment_id and s.status in ('held','makeup');

  att_pct := case when total_sessions > 0
                  then round((hours / total_sessions) * 100, 2)
                  else 0 end;

  -- Best PASSING final-exam score across non-void attempts.
  select max(aa.score) into best_final
  from assessment_attempts aa
  join assessments a on a.id = aa.assessment_id
  where aa.enrollment_id = p_enrollment_id
    and a.kind = 'final_exam'
    and not aa.void
    and aa.passed;
  final_passed := best_final is not null;

  -- Skills: every defined skill must have a current tier; gold for distinction.
  select count(*) into skills_total from skills where program_id = prog.id;

  select count(*) into skills_tiered
  from current_skill_tier cst
  where cst.enrollment_id = p_enrollment_id;

  select count(*) into skills_gold
  from current_skill_tier cst
  where cst.enrollment_id = p_enrollment_id and cst.tier = 'gold';

  all_tiered := (skills_total > 0 and skills_tiered >= skills_total);
  all_gold   := (skills_total > 0 and skills_gold  >= skills_total);

  -- Perfect attendance: zero absences AND zero tardies (excused does NOT
  -- preserve it -- see docs/DECISIONS.md #4).
  perfect := coalesce(led.absences,0) = 0
         and coalesce(led.tardies,0) = 0
         and coalesce(led.excused_absences,0) = 0;

  -- Outcome (Principle #3: literal, deterministic).
  if best_final >= 93 and all_gold and perfect and hours >= prog.total_clock_hours then
    outcome := 'completed_with_distinction';
  elsif final_passed and all_tiered and hours >= prog.total_clock_hours then
    outcome := 'completed';
  else
    outcome := 'not_eligible';
  end if;

  -- Snapshot literal inputs (evidence; §7 "snapshots, not references").
  snap := jsonb_build_object(
    'program_id', prog.id,
    'program_version', prog.version,
    'total_clock_hours', prog.total_clock_hours,
    'clock_hours_earned', hours,
    'attendance_pct', att_pct,
    'absences', coalesce(led.absences,0),
    'tardies', coalesce(led.tardies,0),
    'excused_absences', coalesce(led.excused_absences,0),
    'best_final_exam_score', best_final,
    'final_passed', final_passed,
    'skills_total', skills_total,
    'skills_tiered', skills_tiered,
    'skills_gold', skills_gold,
    'all_skills_gold', all_gold,
    'perfect_attendance', perfect,
    'evaluated_at', now()
  );

  insert into completion_evaluations (
    enrollment_id, clock_hours_earned, attendance_pct, final_exam_score,
    all_skills_gold, perfect_attendance, outcome, criteria_snapshot
  ) values (
    p_enrollment_id, hours, att_pct, best_final,
    all_gold, perfect, outcome, snap
  ) returning id into eval_id;

  return eval_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- issue_certificate(completion_evaluation_id) -> uuid (the certificate row)
-- Allocates the next GAPLESS certificate number atomically. Rejects
-- non-eligible outcomes. PDF rendering is delegated to an edge function; the
-- intended pdf_url is stored and filled in on render.
-- -----------------------------------------------------------------------------
create or replace function issue_certificate(
  p_completion_evaluation_id uuid,
  p_issued_by uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  ce       completion_evaluations%rowtype;
  n        bigint;
  cert_no  text;
  cert_id  uuid;
begin
  select * into ce from completion_evaluations where id = p_completion_evaluation_id;
  if not found then
    raise exception 'issue_certificate: completion evaluation % not found', p_completion_evaluation_id;
  end if;

  if ce.outcome not in ('completed','completed_with_distinction') then
    raise exception 'issue_certificate: outcome "%" is not eligible for a certificate', ce.outcome;
  end if;

  -- Atomic gapless allocation: lock the counter row, then bump.
  update certificate_counter
     set last_number = last_number + 1
   where series = 'default'
  returning last_number into n;

  cert_no := 'TGI-' || lpad(n::text, 6, '0');   -- e.g. TGI-000001

  insert into certificates (
    enrollment_id, completion_evaluation_id, certificate_number, issued_by, pdf_url
  ) values (
    ce.enrollment_id, ce.id, cert_no, p_issued_by,
    'certificates/' || cert_no || '.pdf'        -- rendered async; path reserved
  ) returning id into cert_id;

  return cert_id;
end;
$$;
