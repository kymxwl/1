-- =============================================================================
-- 20260101001900_grading_mode.sql
-- Mark whether an assessment is auto-graded or instructor-graded, so the app can
-- branch: auto exams grade on submit; manual exams are submitted ungraded and
-- graded later by an instructor (written exam, practical exam).
--
-- Column only (default 'auto'); the manual instruments set 'manual' in their
-- content modules (which run after migrations), so this stays a no-op-safe add.
-- =============================================================================

alter table assessments add column if not exists grading text not null default 'auto';
alter table assessments drop constraint if exists assessments_grading_check;
alter table assessments add constraint assessments_grading_check
  check (grading in ('auto', 'manual'));
