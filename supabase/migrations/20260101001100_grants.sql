-- =============================================================================
-- 20260101001100_grants.sql
-- Base privileges for the Supabase client roles. RLS (migration 000900) is the
-- real access boundary; these grants only decide which tables RLS is even
-- consulted for. Everything not granted is unreachable regardless of RLS.
--
-- Model: grant SELECT broadly and let RLS filter rows; grant INSERT only on the
-- append-only record tables students/instructors legitimately write; never
-- grant UPDATE/DELETE on the four immutable tables (the guards migration also
-- revokes them and installs block triggers -- defence in depth).
-- =============================================================================

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant usage on schema public to authenticated;
    grant select on all tables in schema public to authenticated;

    -- Append-only inserts. RLS decides *which* rows each role may add.
    grant insert on attendance_records   to authenticated;  -- instructor/admin (RLS)
    grant insert on assessment_attempts  to authenticated;  -- student/staff (RLS)
    grant insert on skill_evaluations    to authenticated;  -- instructor/admin (RLS)

    -- Curriculum / cohort / session writes for admins & instructors (RLS-gated).
    grant insert, update on cohorts, sessions to authenticated;
    grant insert, update, delete on
      programs, courses, chapters, lessons, resources,
      skills, skill_benchmarks, assessments, assessment_questions
      to authenticated;
    grant insert, update on enrollments to authenticated;

    -- Certificate revocation is a permitted UPDATE (stamps revoked_at/reason);
    -- issuance flows through issue_certificate() (SECURITY DEFINER).
    grant update on certificates to authenticated;

    -- Execute the server-side functions.
    grant execute on function
      clock_hours_for(uuid),
      grade_attempt(uuid),
      record_attendance_correction(uuid, text, int, uuid, text),
      evaluate_completion(uuid),
      issue_certificate(uuid, uuid),
      current_app_role()
      to authenticated;

    -- Default privileges for tables added by future migrations run as this owner.
    alter default privileges in schema public
      grant select on tables to authenticated;
  end if;

  -- anon gets nothing beyond schema usage; the app requires authentication.
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant usage on schema public to anon;
  end if;
end$$;
