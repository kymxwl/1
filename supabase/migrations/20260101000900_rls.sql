-- =============================================================================
-- 20260101000900_rls.sql
-- Section 4 Access Control (Supabase RLS) + hard rules.
--
-- Roles resolved via current_app_role(). student = the authenticated learner,
-- instructor = owns their cohorts, admin = full.
--
-- HARD RULES (spec §4):
--   * No role may UPDATE or DELETE attendance_records, assessment_attempts,
--     skill_evaluations, completion_evaluations. Supersession is an INSERT.
--     Enforced here (no UPDATE/DELETE policies) AND by revoked grants +
--     block triggers in the next migration (defence in depth).
--   * question_bank.correct_answer is unreachable from any client role.
--   * All grading / tier computation runs in SECURITY DEFINER functions.
-- =============================================================================

-- Helper: is the calling user the student behind this enrollment?
create or replace function owns_enrollment(p_enrollment_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from enrollments e
    join students s on s.id = e.student_id
    where e.id = p_enrollment_id and s.profile_id = auth.uid()
  );
$$;

-- Helper: does the calling instructor own the cohort behind this enrollment?
create or replace function instructs_enrollment(p_enrollment_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from enrollments e
    join cohorts c on c.id = e.cohort_id
    where e.id = p_enrollment_id and c.instructor_id = auth.uid()
  );
$$;

create or replace function instructs_session(p_session_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from sessions s
    join cohorts c on c.id = s.cohort_id
    where s.id = p_session_id
      and (s.instructor_id = auth.uid() or c.instructor_id = auth.uid())
  );
$$;

-- Enable RLS everywhere that carries student data.
alter table programs               enable row level security;
alter table courses                enable row level security;
alter table chapters               enable row level security;
alter table lessons                enable row level security;
alter table resources              enable row level security;
alter table cohorts                enable row level security;
alter table enrollments            enable row level security;
alter table sessions               enable row level security;
alter table attendance_records     enable row level security;
alter table question_bank          enable row level security;
alter table assessments            enable row level security;
alter table assessment_questions   enable row level security;
alter table assessment_attempts    enable row level security;
alter table skills                 enable row level security;
alter table skill_benchmarks       enable row level security;
alter table skill_evaluations      enable row level security;
alter table completion_evaluations enable row level security;
alter table certificates           enable row level security;

-- ---------------------------------------------------------------- curriculum
-- students read only visibility=student resources; everyone reads structure.
do $$
begin
  -- programs/courses/chapters/lessons: readable by all authenticated; write admin.
  perform 1;
end$$;

create policy curr_read_programs on programs for select using (true);
create policy curr_read_courses  on courses  for select using (true);
create policy curr_read_chapters on chapters for select using (true);
create policy curr_read_lessons  on lessons  for select using (true);

create policy curr_admin_programs on programs for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy curr_admin_courses on courses for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy curr_admin_chapters on chapters for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy curr_admin_lessons on lessons for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

-- resources: students only see visibility=student; instructors student+instructor; admin all.
create policy res_read on resources for select using (
  current_app_role() = 'admin'
  or (current_app_role() = 'instructor' and visibility in ('student','instructor'))
  or (current_app_role() = 'student' and visibility = 'student')
);
create policy res_admin on resources for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

-- ---------------------------------------------------------------- cohorts/sessions
create policy cohort_read on cohorts for select using (
  current_app_role() = 'admin'
  or instructor_id = auth.uid()
  or exists (select 1 from enrollments e join students s on s.id = e.student_id
             where e.cohort_id = cohorts.id and s.profile_id = auth.uid())
);
create policy cohort_write_admin on cohorts for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy cohort_write_instructor on cohorts for update
  using (instructor_id = auth.uid()) with check (instructor_id = auth.uid());

create policy session_read on sessions for select using (
  current_app_role() = 'admin'
  or instructs_session(sessions.id)
  or exists (select 1 from enrollments e join students s on s.id = e.student_id
             where e.cohort_id = sessions.cohort_id and s.profile_id = auth.uid())
);
create policy session_write_admin on sessions for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy session_write_instructor on sessions for insert
  with check (exists (select 1 from cohorts c where c.id = cohort_id and c.instructor_id = auth.uid()));

-- ---------------------------------------------------------------- enrollments
create policy enroll_read on enrollments for select using (
  current_app_role() = 'admin'
  or instructs_enrollment(enrollments.id)
  or exists (select 1 from students s where s.id = enrollments.student_id and s.profile_id = auth.uid())
);
create policy enroll_admin on enrollments for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

-- ---------------------------------------------------------------- attendance
-- SELECT only here; INSERT below. NO update/delete policy exists anywhere.
create policy att_read on attendance_records for select using (
  current_app_role() = 'admin'
  or owns_enrollment(enrollment_id)
  or instructs_enrollment(enrollment_id)
);
-- instructor inserts for sessions they teach; admin inserts (incl. supersede).
create policy att_insert_instructor on attendance_records for insert with check (
  current_app_role() = 'instructor' and instructs_session(session_id)
);
create policy att_insert_admin on attendance_records for insert with check (
  current_app_role() = 'admin'
);

-- ---------------------------------------------------------------- question_bank
-- NO student/instructor SELECT policy => unreachable. Admin only.
-- Clients read the question_bank_public view (answer key omitted).
create policy qb_admin on question_bank for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

create policy asmt_read on assessments for select using (true);
create policy asmt_admin on assessments for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy asmtq_admin on assessment_questions for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

-- ---------------------------------------------------------------- attempts
create policy attempt_read on assessment_attempts for select using (
  current_app_role() = 'admin'
  or owns_enrollment(enrollment_id)
  or instructs_enrollment(enrollment_id)
);
create policy attempt_insert_student on assessment_attempts for insert with check (
  owns_enrollment(enrollment_id)
);
create policy attempt_insert_staff on assessment_attempts for insert with check (
  current_app_role() in ('instructor','admin')
);

-- ---------------------------------------------------------------- skills
create policy skill_read on skills for select using (true);
create policy skill_admin on skills for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
create policy bench_read on skill_benchmarks for select using (true);
create policy bench_admin on skill_benchmarks for all
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');

create policy skilleval_read on skill_evaluations for select using (
  current_app_role() = 'admin'
  or owns_enrollment(enrollment_id)
  or instructs_enrollment(enrollment_id)
);
create policy skilleval_insert_instructor on skill_evaluations for insert with check (
  current_app_role() = 'instructor' and instructs_enrollment(enrollment_id)
);
create policy skilleval_insert_admin on skill_evaluations for insert with check (
  current_app_role() = 'admin'
);

-- ---------------------------------------------------------------- completion/certs
create policy completion_read on completion_evaluations for select using (
  current_app_role() = 'admin'
  or owns_enrollment(enrollment_id)
  or instructs_enrollment(enrollment_id)
);
-- Inserts happen only through SECURITY DEFINER evaluate_completion(); no direct
-- client INSERT policy is granted.

create policy cert_read on certificates for select using (
  current_app_role() = 'admin'
  or owns_enrollment(enrollment_id)
  or instructs_enrollment(enrollment_id)
);
-- Inserts happen only through issue_certificate(); admin-only direct policy for
-- revocation updates (revocation is a permitted UPDATE -- it is not a record
-- rewrite, it stamps revoked_at/reason).
create policy cert_revoke_admin on certificates for update
  using (current_app_role() = 'admin') with check (current_app_role() = 'admin');
