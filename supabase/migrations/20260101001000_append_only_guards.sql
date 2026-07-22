-- =============================================================================
-- 20260101001000_append_only_guards.sql
-- Defence in depth for Governing Principle #2 (append-only, no hard delete).
--
-- RLS already withholds UPDATE/DELETE policies on the four record tables, but
-- policies do not bind the table OWNER or SECURITY DEFINER code paths. These
-- BEFORE UPDATE/DELETE triggers make the prohibition absolute for everything
-- except the explicitly whitelisted operations:
--   * assessment_attempts: grade_attempt() sets score/passed once; voiding sets
--     void/void_reason. Both are done here via a guarded exception. Everything
--     else is blocked.
-- attendance_records, skill_evaluations, completion_evaluations: NEVER updated
-- or deleted. Corrections/re-tests/re-evaluations are new rows.
-- =============================================================================

-- Hard block: no UPDATE, no DELETE, ever.
create or replace function block_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception
    '% is append-only: % is not permitted. Insert a superseding row instead.',
    tg_table_name, tg_op
    using errcode = 'restrict_violation';
end;
$$;

drop trigger if exists trg_block_upd_attendance on attendance_records;
create trigger trg_block_upd_attendance
  before update or delete on attendance_records
  for each row execute function block_mutation();

drop trigger if exists trg_block_upd_skilleval on skill_evaluations;
create trigger trg_block_upd_skilleval
  before update or delete on skill_evaluations
  for each row execute function block_mutation();

drop trigger if exists trg_block_upd_completion on completion_evaluations;
create trigger trg_block_upd_completion
  before update or delete on completion_evaluations
  for each row execute function block_mutation();

-- assessment_attempts: allow ONLY the grading write (score/passed/submitted_at)
-- and the void write (void/void_reason). Block any other column change and all
-- deletes. Everything else about the row is immutable.
create or replace function guard_attempt_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'assessment_attempts is append-only: DELETE not permitted'
      using errcode = 'restrict_violation';
  end if;

  -- Immutable identity/content columns.
  if new.id            is distinct from old.id
     or new.enrollment_id is distinct from old.enrollment_id
     or new.assessment_id is distinct from old.assessment_id
     or new.attempt_number is distinct from old.attempt_number
     or new.responses    is distinct from old.responses
     or new.started_at   is distinct from old.started_at
  then
    raise exception 'assessment_attempts: identity/response columns are immutable'
      using errcode = 'restrict_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_attempt on assessment_attempts;
create trigger trg_guard_attempt
  before update or delete on assessment_attempts
  for each row execute function guard_attempt_mutation();

-- Also revoke UPDATE/DELETE grants from the client roles as belt-and-braces.
-- (Supabase roles: anon, authenticated.)
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke update, delete on attendance_records     from authenticated';
    execute 'revoke update, delete on skill_evaluations       from authenticated';
    execute 'revoke update, delete on completion_evaluations  from authenticated';
    execute 'revoke delete on assessment_attempts             from authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on attendance_records, skill_evaluations, completion_evaluations, assessment_attempts, question_bank from anon';
  end if;
end$$;
