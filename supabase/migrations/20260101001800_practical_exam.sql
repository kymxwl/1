-- =============================================================================
-- 20260101001800_practical_exam.sql
-- The Ch 25 Final Practical Examination instrument (TGI Manual v1).
--
-- Nine evaluation categories, each scored 1..5 (5 Exceptional … 1 Fail);
-- composite = sum / (5 * categories) * 100; graduate at >= 80% (the practical
-- assessment's passing_score). AUTOMATIC-FAILURE conditions (repeated payout
-- errors, misread showdowns, major game-protection failures, unprofessional
-- conduct, dishonesty) fail the exam regardless of composite.
--
-- Scoring runs in grade_practical_attempt(); the instructor records per-category
-- scores + any auto-fail — the composite and pass/fail are COMPUTED, never
-- typed. evaluate_completion() already reads the best passing final_practical
-- attempt, so this instrument feeds the manual-aligned completion rule.
-- =============================================================================

-- The evaluation categories (program-scoped; from the manual's table).
create table if not exists practical_categories (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references programs(id),
  key         text not null,
  name        text not null,
  standard    text not null,
  max_score   int not null default 5,
  sequence    int not null,
  unique (program_id, key)
);

alter table practical_categories enable row level security;
create policy practical_cat_read on practical_categories for select using (true);
create policy practical_cat_admin on practical_categories for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on practical_categories to authenticated;
    grant insert, update, delete on practical_categories to authenticated; -- admin via RLS
  end if;
end$$;

-- -----------------------------------------------------------------------------
-- grade_practical_attempt(attempt_id) -> numeric
-- The instructor's per-category scores are recorded ONCE at attempt creation in
-- responses = { "practical_scores": {key:1..5}, "auto_fail": bool, "note": .. }
-- (write-once, per the append-only guard). This computes the composite and
-- writes score/passed only. auto_fail forces a fail regardless of composite.
-- -----------------------------------------------------------------------------
create or replace function grade_practical_attempt(p_attempt_id uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  att       assessment_attempts%rowtype;
  asmt      assessments%rowtype;
  prog_id   uuid;
  scores    jsonb;
  auto_fail boolean;
  total     int := 0;
  awarded   numeric := 0;
  composite numeric(5,2);
  c         record;
begin
  select * into att from assessment_attempts where id = p_attempt_id;
  if not found then
    raise exception 'grade_practical_attempt: attempt % not found', p_attempt_id;
  end if;
  if att.void then
    raise exception 'grade_practical_attempt: attempt % is void', p_attempt_id;
  end if;

  select * into asmt from assessments where id = att.assessment_id;
  if asmt.kind <> 'final_practical' then
    raise exception 'grade_practical_attempt: assessment % is not a final_practical', att.assessment_id;
  end if;
  if asmt.is_secure and att.proctored_by is null then
    raise exception 'grade_practical_attempt: secure assessment requires proctored_by';
  end if;

  if not (
    current_app_role() = 'admin'
    or instructs_enrollment(att.enrollment_id)
    or att.proctored_by = auth.uid()
  ) then
    raise exception 'grade_practical_attempt: only the proctor, the cohort instructor, or an admin may grade';
  end if;

  scores    := coalesce(att.responses -> 'practical_scores', '{}'::jsonb);
  auto_fail := coalesce((att.responses ->> 'auto_fail')::boolean, false);
  prog_id   := asmt.program_id;

  for c in select key, max_score from practical_categories where program_id = prog_id loop
    total := total + c.max_score;
    awarded := awarded + least(greatest(coalesce((scores ->> c.key)::numeric, 0), 0), c.max_score);
  end loop;

  if total = 0 then
    raise exception 'grade_practical_attempt: no practical categories defined for this program';
  end if;

  composite := round((awarded / total) * 100, 2);

  update assessment_attempts
     set score = composite,
         passed = (composite >= asmt.passing_score and not auto_fail),
         submitted_at = coalesce(submitted_at, now())
   where id = p_attempt_id;

  return composite;
end;
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function grade_practical_attempt(uuid) to authenticated;
  end if;
end$$;
