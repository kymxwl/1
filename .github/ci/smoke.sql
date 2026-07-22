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
