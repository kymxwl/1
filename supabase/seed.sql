-- =============================================================================
-- seed.sql  --  Demo data for the TGI LMS.
-- Idempotent-ish: safe to run on a fresh `supabase db reset`.
-- Order matters: curriculum + policy BEFORE the cohort (curriculum freezes once
-- a cohort pins the program).
-- =============================================================================

-- ---- Profiles / identities -------------------------------------------------
insert into profiles (id, role, full_name, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin',      'Dana Admin',        'admin@tgi.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'instructor', 'Ivan Instructor',   'ivan@tgi.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'student',    'Sam Student',       'sam@tgi.test'),
  ('00000000-0000-0000-0000-0000000000c2', 'student',    'Riley Student',     'riley@tgi.test')
on conflict (id) do nothing;

insert into students (id, profile_id, first_name, last_name) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'Sam',   'Student'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c2', 'Riley', 'Student')
on conflict (id) do nothing;

insert into enrollment_agreements (id, student_id, signed_at, is_complete) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', now(), true),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000d2', now(), true)
on conflict (id) do nothing;

insert into payment_records (student_id, pathway, is_approved) values
  ('00000000-0000-0000-0000-0000000000d1', 'card', true),
  ('00000000-0000-0000-0000-0000000000d2', 'wioa', true);

-- ---- Curriculum: program, course, 25 chapters, lessons --------------------
-- Canonical content lives in content/curriculum_2026_1.sql (the institute's
-- editable source of truth). Included here so the demo/local DB uses exactly
-- the same 25 chapters as a real deployment. Runs before any cohort exists,
-- so the curriculum-freeze trigger does not block it. `\ir` resolves relative
-- to this file's directory (supabase/).
\ir content/curriculum_2026_1.sql

-- Appendix L — the real 100-question written final (instructor-graded).
\ir content/exam_appendix_l_2026_1.sql

-- Ch 25 Final Practical Examination (nine categories, composite >= 80%).
\ir content/practical_exam_2026_1.sql

-- Appendix C — Hand Reading Workbook (50 self-check flashcards, Ch 20).
\ir content/hand_reading_workbook_2026_1.sql

-- Appendix A (glossary) + Appendix B (quick-reference charts) as study cards.
\ir content/reference_2026_1.sql

-- Presentational sections (TGI Standard, oaths, instructor forms) as resources.
\ir content/handbook_2026_1.sql

-- A couple of student-visible resources.
insert into resources (owner_type, owner_id, kind, title, url, visibility)
select 'chapter', ch.id, 'flashcards', ch.title || ' Flash Cards',
       'https://decks.tgi.test/ch' || ch.number, 'student'
from chapters ch
where ch.course_id = '00000000-0000-0000-0000-000000000010' and ch.number in (10, 11);

-- Flash cards (study content) for Ch 10 Pot Management & Side Pot Construction.
-- Separate from question_bank so nothing here can leak a secure exam key.
insert into flashcards (chapter_id, front, back, sequence)
select ch.id, c.front, c.back, c.seq
from (values
  ('Main pot', 'The pot every contesting player is eligible to win.', 1),
  ('Side pot', 'A separate pot built when a player is all-in for less than a full call.', 2),
  ('Cut card', 'The solid card used to protect the bottom of the deck.', 3),
  ('Capped bet', 'A player''s contribution limited by their all-in amount.', 4)
) as c(front, back, seq)
join chapters ch on ch.number = 10 and ch.course_id = '00000000-0000-0000-0000-000000000010';

-- Skills + benchmarks now live in content/curriculum_2026_1.sql (from the
-- manual's Performance Benchmarks table), \ir-included above. The demo skill
-- evaluation below references skill 101 (Full Shuffle).

-- ---- Assessments: a chapter-10 quiz + Form A / Form B finals ---------------
insert into assessments (id, program_id, kind, form_code, title, question_count, passing_score, time_limit_minutes, is_secure, max_attempts, randomize_order) values
  ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000001','chapter_quiz', null, 'Chapter 10 Quiz: Pot Management & Side Pots', 3, 70, 15, false, 5, true),
  ('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000001','final_exam',  'A',  'Final Exam -- Form A (Appendix L)', 3, 75, 120, true, 1, false),
  ('00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000001','final_exam',  'B',  'Final Exam -- Form B (Secure)', 3, 75, 120, true, 1, false)
on conflict (id) do nothing;

-- Questions (correct_answer stays server-side; clients get question_bank_public)
insert into question_bank (id, program_id, chapter_id, stem, type, options, correct_answer, explanation, difficulty)
select
  q.id::uuid, '00000000-0000-0000-0000-000000000001', ch.id, q.stem, q.type,
  q.options::jsonb, q.correct::jsonb, q.expl, 'medium'
from (values
  ('00000000-0000-0000-0000-000000000301', 10,
   'When is a side pot created?', 'multiple_choice',
   '[{"key":"a","text":"Every hand"},{"key":"b","text":"When a player is all-in for less than a call"},{"key":"c","text":"Only in tournaments"}]',
   '"b"', 'A side pot forms when a player is all-in and others continue betting.'),
  ('00000000-0000-0000-0000-000000000302', 10,
   'The main pot can be won by any player still in the hand.', 'true_false',
   '[{"key":"true","text":"True"},{"key":"false","text":"False"}]',
   '"true"', 'All contesting players are eligible for the main pot.'),
  ('00000000-0000-0000-0000-000000000303', 10,
   'Name the chip the dealer uses to protect the deck between hands.', 'short_answer',
   '[]', '["cut card","cutting card"]', 'The cut card protects the bottom of the deck.')
) as q(id, chnum, stem, type, options, correct, expl)
join chapters ch on ch.number = q.chnum and ch.course_id = '00000000-0000-0000-0000-000000000010'
on conflict (id) do nothing;

-- Map the same 3 questions to the chapter quiz and both final forms (demo).
insert into assessment_questions (assessment_id, question_id, sequence)
select a.id::uuid, q.qid::uuid, q.seq
from (values
  ('00000000-0000-0000-0000-000000000301', 1),
  ('00000000-0000-0000-0000-000000000302', 2),
  ('00000000-0000-0000-0000-000000000303', 3)
) as q(qid, seq)
cross join (values
  ('00000000-0000-0000-0000-000000000201'),
  ('00000000-0000-0000-0000-000000000202'),
  ('00000000-0000-0000-0000-000000000203')
) as a(id)
on conflict do nothing;

-- ---- Cohort + enrollment + a few sessions ----------------------------------
insert into cohorts (id, program_id, name, start_date, end_date, instructor_id, capacity, status, location) values
  ('00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000001','2026-A','2026-02-02','2026-03-13','00000000-0000-0000-0000-0000000000b1',24,'active','Austin Campus')
on conflict (id) do nothing;

insert into enrollments (id, student_id, cohort_id, status, tuition_rate, enrollment_agreement_id) values
  ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-000000000401','active','standard','00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-000000000502','00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-000000000401','active','industry','00000000-0000-0000-0000-0000000000e2')
on conflict (id) do nothing;

-- Two held sessions (4 clock hours each).
insert into sessions (id, cohort_id, session_date, start_time, end_time, scheduled_clock_hours, instructor_id, status, session_type) values
  ('00000000-0000-0000-0000-000000000601','00000000-0000-0000-0000-000000000401','2026-02-02','09:00','13:00',4,'00000000-0000-0000-0000-0000000000b1','held','lecture'),
  ('00000000-0000-0000-0000-000000000602','00000000-0000-0000-0000-000000000401','2026-02-03','09:00','13:00',4,'00000000-0000-0000-0000-0000000000b1','held','lab')
on conflict (id) do nothing;

-- Attendance (hours computed by trigger: 240 min -> 4.00; 200 min -> 3.25).
insert into attendance_records (enrollment_id, session_id, status, minutes_present, recorded_by) values
  ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000601','present', 240, '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000602','tardy',   200, '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-000000000502','00000000-0000-0000-0000-000000000601','present', 240, '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-000000000502','00000000-0000-0000-0000-000000000602','absent',  0,   '00000000-0000-0000-0000-0000000000b1');

-- A skill evaluation (tier computed by trigger: 13s shuffle -> gold).
insert into skill_evaluations (enrollment_id, skill_id, evaluator_id, raw_metric, session_id) values
  ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-0000000000b1', 13, '00000000-0000-0000-0000-000000000602');
