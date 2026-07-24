-- =============================================================================
-- 20260101001700_completion_manual.sql
-- Align completion & distinction with TGI Manual v1 (Program Completion
-- Requirements + Graduate Distinction), replacing the original spec rule.
--
-- Manual COMPLETION requires: all training hours; pass the WRITTEN exam; pass
-- the PRACTICAL exam (>= 80% composite); at least SILVER in all timed/accuracy
-- skills; attendance >= 90%. Manual DISTINCTION requires: 93%+ on BOTH written
-- AND practical; GOLD in all skills; NO game-protection failures; perfect
-- attendance.
--
-- This models the two signals the manual adds — a practical exam (assessment
-- kind 'final_practical') and game-protection failures — and rewrites
-- evaluate_completion() accordingly. Gates that need human attestation
-- (professional conduct, instructor sign-off, per-variant competency) are NOT
-- auto-decided here; see docs/DECISIONS.md.
-- =============================================================================

-- Allow a practical-exam assessment kind.
alter table assessments drop constraint if exists assessments_kind_check;
alter table assessments add constraint assessments_kind_check
  check (kind in ('chapter_quiz','practice','final_exam','final_practical'));

-- Game-protection failures — append-only evidence. Distinction requires zero.
create table if not exists game_protection_incidents (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references enrollments(id),
  session_id    uuid references sessions(id),
  recorded_by   uuid references profiles(id),
  recorded_at   timestamptz not null default now(),
  severity      text not null default 'failure' check (severity in ('warning','failure')),
  note          text not null
);
create index if not exists idx_gpi_enrollment on game_protection_incidents(enrollment_id);

alter table game_protection_incidents enable row level security;

create policy gpi_read on game_protection_incidents for select using (
  current_app_role() = 'admin'
  or owns_enrollment(enrollment_id)
  or instructs_enrollment(enrollment_id)
);
create policy gpi_insert_staff on game_protection_incidents for insert with check (
  current_app_role() = 'admin'
  or (current_app_role() = 'instructor' and instructs_enrollment(enrollment_id))
);

-- Append-only: no UPDATE/DELETE (block trigger + revoked grants).
drop trigger if exists trg_block_upd_gpi on game_protection_incidents;
create trigger trg_block_upd_gpi
  before update or delete on game_protection_incidents
  for each row execute function block_mutation();

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select, insert on game_protection_incidents to authenticated;
    revoke update, delete on game_protection_incidents from authenticated;
  end if;
end$$;

-- -----------------------------------------------------------------------------
-- evaluate_completion(enrollment_id) — manual-aligned outcome + snapshot.
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
  scheduled      numeric;
  hours          numeric(6,2);
  att_pct        numeric(5,2);
  written_best   numeric(5,2);
  written_passed boolean;
  practical_best numeric(5,2);
  practical_passed boolean;
  skills_total   int;
  skills_silver  int;   -- silver or gold
  skills_gold    int;
  all_silver     boolean;
  all_gold       boolean;
  gp_failures    int;
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

  select coalesce(sum(s.scheduled_clock_hours), 0) into scheduled
  from sessions s join enrollments e on e.cohort_id = s.cohort_id
  where e.id = p_enrollment_id and s.status in ('held','makeup');
  att_pct := case when scheduled > 0 then round((hours / scheduled) * 100, 2) else 0 end;

  -- Written exam: best passing score across non-void final_exam attempts.
  select max(aa.score) into written_best
  from assessment_attempts aa join assessments a on a.id = aa.assessment_id
  where aa.enrollment_id = p_enrollment_id and a.kind = 'final_exam'
    and not aa.void and aa.passed;
  written_passed := written_best is not null;

  -- Practical exam: best passing score across non-void final_practical attempts.
  select max(aa.score) into practical_best
  from assessment_attempts aa join assessments a on a.id = aa.assessment_id
  where aa.enrollment_id = p_enrollment_id and a.kind = 'final_practical'
    and not aa.void and aa.passed;
  practical_passed := practical_best is not null;

  -- Skills: Silver+ (completion) and Gold (distinction) across all defined skills.
  select count(*) into skills_total from skills where program_id = prog.id;
  select count(*) into skills_silver
  from current_skill_tier cst
  where cst.enrollment_id = p_enrollment_id and cst.tier in ('silver','gold');
  select count(*) into skills_gold
  from current_skill_tier cst
  where cst.enrollment_id = p_enrollment_id and cst.tier = 'gold';
  all_silver := (skills_total > 0 and skills_silver >= skills_total);
  all_gold   := (skills_total > 0 and skills_gold   >= skills_total);

  select count(*) into gp_failures
  from game_protection_incidents
  where enrollment_id = p_enrollment_id and severity = 'failure';

  perfect := coalesce(led.absences,0) = 0
         and coalesce(led.tardies,0) = 0
         and coalesce(led.excused_absences,0) = 0;

  -- Manual-aligned outcome.
  if written_best >= 93 and practical_best >= 93 and all_gold and perfect
     and gp_failures = 0 and hours >= prog.total_clock_hours then
    outcome := 'completed_with_distinction';
  elsif written_passed and practical_passed and all_silver
     and att_pct >= 90 and hours >= prog.total_clock_hours then
    outcome := 'completed';
  else
    outcome := 'not_eligible';
  end if;

  snap := jsonb_build_object(
    'rule_source', 'TGI Manual v1',
    'program_id', prog.id, 'program_version', prog.version,
    'total_clock_hours', prog.total_clock_hours, 'clock_hours_earned', hours,
    'attendance_pct', att_pct, 'attendance_min', 90,
    'absences', coalesce(led.absences,0), 'tardies', coalesce(led.tardies,0),
    'excused_absences', coalesce(led.excused_absences,0),
    'written_best', written_best, 'written_passed', written_passed,
    'practical_best', practical_best, 'practical_passed', practical_passed,
    'skills_total', skills_total, 'skills_silver_plus', skills_silver,
    'skills_gold', skills_gold, 'all_skills_silver', all_silver, 'all_skills_gold', all_gold,
    'game_protection_failures', gp_failures, 'perfect_attendance', perfect,
    'evaluated_at', now()
  );

  insert into completion_evaluations (
    enrollment_id, clock_hours_earned, attendance_pct, final_exam_score,
    all_skills_gold, perfect_attendance, outcome, criteria_snapshot
  ) values (
    p_enrollment_id, hours, att_pct, written_best,
    all_gold, perfect, outcome, snap
  ) returning id into eval_id;

  return eval_id;
end;
$$;
