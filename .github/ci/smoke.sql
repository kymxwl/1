-- CI smoke assertions. Runs after migrations + seed. Any failed invariant
-- raises an exception and fails the job. Mirrors the checks validated locally.
\set ON_ERROR_STOP on

do $$
declare
  hours   numeric;
  tier    text;
  qb_cols int;
begin
  -- Ledger: Sam (…501) = 4.00 present + 3.25 (200 min tardy, round-down ¼ hr).
  select clock_hours_earned into hours
  from clock_hour_ledger where enrollment_id = '00000000-0000-0000-0000-000000000501';
  if hours is distinct from 7.25 then
    raise exception 'SMOKE FAIL: expected ledger 7.25, got %', hours;
  end if;

  -- Skill tier: 13 s shuffle computed to gold.
  select cst.tier into tier
  from current_skill_tier cst where cst.enrollment_id = '00000000-0000-0000-0000-000000000501';
  if tier is distinct from 'gold' then
    raise exception 'SMOKE FAIL: expected tier gold, got %', tier;
  end if;

  -- Answer key isolation: question_bank_public must not expose the key columns.
  select count(*) into qb_cols
  from information_schema.columns
  where table_name = 'question_bank_public'
    and column_name in ('correct_answer', 'explanation');
  if qb_cols <> 0 then
    raise exception 'SMOKE FAIL: question_bank_public exposes answer-key columns';
  end if;

  raise notice 'SMOKE OK: ledger=7.25, tier=gold, answer keys isolated';
end$$;

-- Grading + proctor enforcement (secure exam without a proctor must be rejected).
do $$
declare
  ok boolean := false;
begin
  insert into assessment_attempts (id, enrollment_id, assessment_id, attempt_number, responses)
  values ('00000000-0000-0000-0000-0000000c1001','00000000-0000-0000-0000-000000000502',
          '00000000-0000-0000-0000-000000000203', 1, '{}');
  begin
    perform grade_attempt('00000000-0000-0000-0000-0000000c1001');
  exception when others then
    ok := true;   -- expected: requires proctored_by
  end;
  if not ok then
    raise exception 'SMOKE FAIL: secure exam graded without a proctor';
  end if;
  raise notice 'SMOKE OK: secure exam without proctor rejected';
end$$;

-- Append-only: UPDATE on attendance_records must be blocked.
do $$
declare
  ok boolean := false;
begin
  begin
    update attendance_records set status = 'present'
    where id = (select id from attendance_records limit 1);
  exception when others then
    ok := true;   -- expected: block_mutation()
  end;
  if not ok then
    raise exception 'SMOKE FAIL: attendance_records accepted an UPDATE';
  end if;
  raise notice 'SMOKE OK: attendance UPDATE blocked';
end$$;

-- Session-calendar generation (M2): expand a Mon–Fri template over the seeded
-- cohort and confirm rows appear, existing sessions are not duplicated.
do $$
declare
  n           int;
  before_cnt  int;
  after_cnt   int;
begin
  select count(*) into before_cnt
  from sessions where cohort_id = '00000000-0000-0000-0000-000000000401';

  -- 08:00 start (distinct from the seeded 09:00 rows), Mon–Fri.
  select generate_cohort_sessions(
    '00000000-0000-0000-0000-000000000401',
    array[1,2,3,4,5], '08:00', '12:00', 4, 'lecture'
  ) into n;

  select count(*) into after_cnt
  from sessions where cohort_id = '00000000-0000-0000-0000-000000000401';

  if n <= 0 or after_cnt <> before_cnt + n then
    raise exception 'SMOKE FAIL: session generation inserted % (before %, after %)', n, before_cnt, after_cnt;
  end if;

  -- Idempotent: a second run over the same template inserts nothing.
  if generate_cohort_sessions(
       '00000000-0000-0000-0000-000000000401',
       array[1,2,3,4,5], '08:00', '12:00', 4, 'lecture'
     ) <> 0 then
    raise exception 'SMOKE FAIL: session generation is not idempotent';
  end if;

  raise notice 'SMOKE OK: session generation inserted % rows, idempotent on re-run', n;
end$$;

-- Practice feedback (M4): a graded NON-SECURE attempt yields explanations;
-- a SECURE assessment never does.
do $$
declare
  fb        jsonb;
  secure_ok boolean := false;
begin
  -- Non-secure chapter-12 quiz attempt for Sam (…501), graded.
  insert into assessment_attempts (id, enrollment_id, assessment_id, attempt_number, responses)
  values ('00000000-0000-0000-0000-0000000fb001','00000000-0000-0000-0000-000000000501',
          '00000000-0000-0000-0000-000000000201', 1,
          '{"00000000-0000-0000-0000-000000000301":"b","00000000-0000-0000-0000-000000000302":"true","00000000-0000-0000-0000-000000000303":"cut card"}');
  perform grade_attempt('00000000-0000-0000-0000-0000000fb001');

  -- Act as Sam so the ownership check in attempt_feedback passes.
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', true);
  fb := attempt_feedback('00000000-0000-0000-0000-0000000fb001');
  if jsonb_array_length(fb) <> 3 then
    raise exception 'SMOKE FAIL: expected 3 feedback items, got %', jsonb_array_length(fb);
  end if;
  if (fb -> 0 ->> 'explanation') is null then
    raise exception 'SMOKE FAIL: feedback missing explanation';
  end if;

  -- Secure exam: feedback must be refused even after grading.
  insert into assessment_attempts (id, enrollment_id, assessment_id, attempt_number, proctored_by, responses)
  values ('00000000-0000-0000-0000-0000000fb002','00000000-0000-0000-0000-000000000501',
          '00000000-0000-0000-0000-000000000202', 2, '00000000-0000-0000-0000-0000000000b1', '{}');
  perform grade_attempt('00000000-0000-0000-0000-0000000fb002');
  begin
    perform attempt_feedback('00000000-0000-0000-0000-0000000fb002');
  exception when others then
    secure_ok := true;   -- expected: refused for secure assessments
  end;
  if not secure_ok then
    raise exception 'SMOKE FAIL: attempt_feedback exposed a secure exam';
  end if;

  raise notice 'SMOKE OK: practice feedback returns explanations, secure exam refused';
end$$;

-- Auth (Phase 2): set_user_role is admin-gated. A non-admin cannot elevate;
-- an admin can. Uses seeded profiles (a1 admin, c2 student/Riley).
do $$
declare
  blocked boolean := false;
begin
  -- As a student (Sam, …c1): elevation must be refused.
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', true);
  begin
    perform set_user_role('00000000-0000-0000-0000-0000000000c2', 'instructor');
  exception when others then
    blocked := true;   -- expected: admin role required
  end;
  if not blocked then
    raise exception 'SMOKE FAIL: a non-admin changed a user role';
  end if;

  -- As an admin (Dana, …a1): elevation applies, then restore.
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
  perform set_user_role('00000000-0000-0000-0000-0000000000c2', 'instructor');
  if (select role from profiles where id = '00000000-0000-0000-0000-0000000000c2') <> 'instructor' then
    raise exception 'SMOKE FAIL: admin role change did not apply';
  end if;
  perform set_user_role('00000000-0000-0000-0000-0000000000c2', 'student');  -- restore

  raise notice 'SMOKE OK: set_user_role is admin-gated';
end$$;

-- Written exam (Appendix L): 100 instructor-graded questions. grade_attempt
-- must REFUSE it; grade_written_attempt computes from per-question marks.
do $$
declare
  qcount   int;
  refused  boolean := false;
  marks    jsonb;
  score    numeric;
begin
  select count(*) into qcount
  from assessment_questions where assessment_id = '00000000-0000-0000-0000-000000000204';
  if qcount <> 100 then
    raise exception 'SMOKE FAIL: Appendix L exam has % questions, expected 100', qcount;
  end if;

  -- Proctored attempt on the written final for Sam (…501).
  insert into assessment_attempts (id, enrollment_id, assessment_id, attempt_number, proctored_by, responses)
  values ('00000000-0000-0000-0000-00000000e204','00000000-0000-0000-0000-000000000501',
          '00000000-0000-0000-0000-000000000204', 1, '00000000-0000-0000-0000-0000000000b1', '{}');

  -- Auto-grader must refuse a manual-graded exam.
  begin
    perform grade_attempt('00000000-0000-0000-0000-00000000e204');
  exception when others then
    refused := true;
  end;
  if not refused then
    raise exception 'SMOKE FAIL: grade_attempt did not refuse the instructor-graded exam';
  end if;

  -- Instructor marks the first 80 questions correct -> 80%.
  select jsonb_object_agg(question_id::text, case when seq <= 80 then 1 else 0 end) into marks
  from (
    select question_id, row_number() over (order by sequence) as seq
    from assessment_questions where assessment_id = '00000000-0000-0000-0000-000000000204'
  ) t;

  -- Grade as the proctor (Ivan, …b1).
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', true);
  score := grade_written_attempt('00000000-0000-0000-0000-00000000e204', marks);
  if score <> 80.00 then
    raise exception 'SMOKE FAIL: written score %, expected 80.00', score;
  end if;
  if (select passed from assessment_attempts where id = '00000000-0000-0000-0000-00000000e204') is not true then
    raise exception 'SMOKE FAIL: 80%% written exam not marked passed (pass=70)';
  end if;

  raise notice 'SMOKE OK: written exam refuses auto-grade; grade_written_attempt computes 80%%';
end$$;

-- Completion (manual-aligned): evaluate_completion runs and, for the partially
-- complete demo student, yields not_eligible; the snapshot cites the manual.
do $$
declare
  ce   uuid;
  row  completion_evaluations%rowtype;
begin
  ce := evaluate_completion('00000000-0000-0000-0000-000000000501');
  select * into row from completion_evaluations where id = ce;
  if row.outcome <> 'not_eligible' then
    raise exception 'SMOKE FAIL: demo completion outcome %, expected not_eligible', row.outcome;
  end if;
  if (row.criteria_snapshot ->> 'rule_source') <> 'TGI Manual v1' then
    raise exception 'SMOKE FAIL: completion snapshot missing manual rule_source';
  end if;
  -- The manual adds a practical-exam gate the demo student has not met.
  if (row.criteria_snapshot ->> 'practical_passed')::boolean is not false then
    raise exception 'SMOKE FAIL: expected practical_passed=false for demo student';
  end if;
  raise notice 'SMOKE OK: manual-aligned completion evaluates (demo -> not_eligible)';
end$$;

-- Practical exam (Ch 25): composite computed from per-category 1..5 scores;
-- an automatic-failure flag fails regardless of composite.
do $$
declare
  score numeric;
  passed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', true);

  -- All nine categories = 5  ->  composite 100, passed.
  insert into assessment_attempts (id, enrollment_id, assessment_id, attempt_number, proctored_by, responses)
  values ('00000000-0000-0000-0000-00000000e205','00000000-0000-0000-0000-000000000501',
          '00000000-0000-0000-0000-000000000205', 1, '00000000-0000-0000-0000-0000000000b1',
          jsonb_build_object('practical_scores', (
             select jsonb_object_agg(key, 5) from practical_categories
             where program_id='00000000-0000-0000-0000-000000000001'), 'auto_fail', false));
  score := grade_practical_attempt('00000000-0000-0000-0000-00000000e205');
  if score <> 100.00 then raise exception 'SMOKE FAIL: practical composite %, expected 100', score; end if;
  select assessment_attempts.passed into passed from assessment_attempts where id='00000000-0000-0000-0000-00000000e205';
  if passed is not true then raise exception 'SMOKE FAIL: all-5 practical not passed'; end if;

  -- All 5s but auto_fail = true  ->  composite 100 yet NOT passed.
  insert into assessment_attempts (id, enrollment_id, assessment_id, attempt_number, proctored_by, responses)
  values ('00000000-0000-0000-0000-00000000e206','00000000-0000-0000-0000-000000000502',
          '00000000-0000-0000-0000-000000000205', 1, '00000000-0000-0000-0000-0000000000b1',
          jsonb_build_object('practical_scores', (
             select jsonb_object_agg(key, 5) from practical_categories
             where program_id='00000000-0000-0000-0000-000000000001'), 'auto_fail', true));
  perform grade_practical_attempt('00000000-0000-0000-0000-00000000e206');
  select assessment_attempts.passed into passed from assessment_attempts where id='00000000-0000-0000-0000-00000000e206';
  if passed is not false then raise exception 'SMOKE FAIL: auto_fail practical was marked passed'; end if;

  raise notice 'SMOKE OK: practical composite computed; automatic-failure overrides';
end$$;
