-- =============================================================================
-- 20260101001300_cohort_sessions.sql
-- M2 session-calendar generation.
--
-- generate_cohort_sessions() expands a weekly schedule template across a
-- cohort's [start_date, end_date] into concrete `sessions` rows. Sessions are
-- ordinary mutable schedule (not append-only regulatory records), so this runs
-- with the CALLER's privileges — RLS on `sessions` (admin: all; instructor:
-- own cohorts) is the authorization boundary. Idempotent: a session already
-- present for the same (cohort, date, start_time) is skipped, so re-running
-- after extending the date range only fills the gaps.
-- =============================================================================

create or replace function generate_cohort_sessions(
  p_cohort_id            uuid,
  p_weekdays             int[],          -- ISO dow: 1=Mon … 7=Sun
  p_start_time           time,
  p_end_time             time,
  p_scheduled_clock_hours numeric,
  p_session_type         text default 'lecture'
) returns int
language plpgsql
as $$
declare
  co        cohorts%rowtype;
  d         date;
  inserted  int := 0;
begin
  select * into co from cohorts where id = p_cohort_id;
  if not found then
    raise exception 'generate_cohort_sessions: cohort % not found', p_cohort_id;
  end if;
  if p_end_time <= p_start_time then
    raise exception 'generate_cohort_sessions: end_time must be after start_time';
  end if;
  if p_weekdays is null or array_length(p_weekdays, 1) is null then
    raise exception 'generate_cohort_sessions: at least one weekday is required';
  end if;

  for d in
    select gs::date
    from generate_series(co.start_date, co.end_date, interval '1 day') gs
    where extract(isodow from gs)::int = any (p_weekdays)
  loop
    -- Skip if a session already exists for this cohort/date/start_time.
    if not exists (
      select 1 from sessions
      where cohort_id = p_cohort_id
        and session_date = d
        and start_time = p_start_time
    ) then
      insert into sessions (
        cohort_id, session_date, start_time, end_time,
        scheduled_clock_hours, instructor_id, status, session_type
      ) values (
        p_cohort_id, d, p_start_time, p_end_time,
        p_scheduled_clock_hours, co.instructor_id, 'scheduled', p_session_type
      );
      inserted := inserted + 1;
    end if;
  end loop;

  return inserted;
end;
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function
      generate_cohort_sessions(uuid, int[], time, time, numeric, text)
      to authenticated;
  end if;
end$$;
