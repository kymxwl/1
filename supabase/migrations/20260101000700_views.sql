-- =============================================================================
-- 20260101000700_views.sql
-- Canonical read surfaces (spec §2.3, §2.4, §2.5).
--   * clock_hour_ledger      -- current (non-superseded) hours per enrollment
--   * current_skill_tier     -- highest current tier per enrollment/skill
--   * question_bank_public   -- questions WITHOUT correct_answer/explanation
--
-- "current" = a row that no other row supersedes.
-- =============================================================================

-- A row is superseded if another attendance row points at it via supersedes_id.
create or replace view attendance_current as
  select ar.*
  from attendance_records ar
  where not exists (
    select 1 from attendance_records s where s.supersedes_id = ar.id
  );

comment on view attendance_current is
  'Non-superseded attendance rows. The basis for the clock-hour ledger.';

-- clock_hour_ledger: THE number on every official document. Makeup hours attach
-- to the original missed session, but for the enrollment total they simply sum
-- (the makeup row carries the earned hours; the original absent row earned 0).
create or replace view clock_hour_ledger as
  select
    e.id                                             as enrollment_id,
    e.cohort_id,
    sum(ac.clock_hours_earned)                       as clock_hours_earned,
    count(*) filter (where ac.status = 'absent')     as absences,
    count(*) filter (where ac.status = 'tardy')      as tardies,
    count(*) filter (where ac.status = 'excused')    as excused_absences,
    count(*) filter (where ac.status = 'left_early') as left_early_count
  from enrollments e
  left join attendance_current ac on ac.enrollment_id = e.id
  group by e.id, e.cohort_id;

-- Highest current tier per enrollment/skill. Ranks gold > silver > bronze;
-- ignores evaluations that reached no tier (tier_awarded is null).
create or replace view current_skill_tier as
  with cur as (
    select se.*
    from skill_evaluations se
    where not exists (
      select 1 from skill_evaluations s where s.supersedes_id = se.id
    )
    and se.tier_awarded is not null
  ), ranked as (
    select
      enrollment_id, skill_id, tier_awarded,
      row_number() over (
        partition by enrollment_id, skill_id
        order by case tier_awarded when 'gold' then 3 when 'silver' then 2 else 1 end desc,
                 evaluated_at desc
      ) as rn
    from cur
  )
  select enrollment_id, skill_id, tier_awarded as tier
  from ranked
  where rn = 1;

-- Answer-key-safe projection of the question bank. Clients read THIS, never
-- question_bank (Principle #4).
create or replace view question_bank_public as
  select id, program_id, chapter_id, stem, type, options, difficulty, is_active
  from question_bank
  where is_active;

comment on view question_bank_public is
  'Client-facing questions. Deliberately omits correct_answer and explanation.';
