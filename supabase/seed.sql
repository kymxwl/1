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

-- ---- Program / course ------------------------------------------------------
insert into programs (id, name, version, total_clock_hours, is_active, effective_date) values
  ('00000000-0000-0000-0000-000000000001', 'Professional Poker Dealer', '2026.1', 100, true, '2026-01-01')
on conflict (id) do nothing;

insert into attendance_policies (program_id) values
  ('00000000-0000-0000-0000-000000000001')
on conflict (program_id) do nothing;   -- defaults = resolved decisions

insert into courses (id, program_id, name, sequence, clock_hours) values
  ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001',
   'Poker Dealing Core', 1, 100)
on conflict (id) do nothing;

-- ---- 25 chapters (maps to the manual) --------------------------------------
insert into chapters (course_id, number, title, sequence, clock_hours, manual_page_ref)
select
  '00000000-0000-0000-0000-000000000010',
  n,
  title,
  n,
  4,                              -- 25 * 4 = 100 clock hours
  'Manual p.' || (n * 10)::text
from (values
  (1,'Table Setup & Chip Handling'),
  (2,'The Deck: Inspection, Wash & Verification'),
  (3,'Standard Shuffle Sequence'),
  (4,'The Riffle, Strip & Box'),
  (5,'Cutting the Deck & The Cut Card'),
  (6,'Pitching Cards & Delivery Mechanics'),
  (7,'Reading the Board & Hand Rankings'),
  (8,'Texas Hold''em Dealing Procedure'),
  (9,'Omaha Dealing Procedure'),
  (10,'Seven-Card Stud Procedure'),
  (11,'Managing the Button & Blinds'),
  (12,'Pot Management & Pot Sizing'),
  (13,'Side Pot Construction'),
  (14,'Collecting the Rake & Drop'),
  (15,'Awarding the Pot & Odd Chips'),
  (16,'Handling All-In Situations'),
  (17,'Splitting Pots & Chopping'),
  (18,'Tournament Dealing Fundamentals'),
  (19,'Blind Structures & Clock Management'),
  (20,'Chip Race & Color-Up Procedure'),
  (21,'Player Etiquette & Table Control'),
  (22,'Handling Disputes & Floor Calls'),
  (23,'Irregularities, Misdeals & Penalties'),
  (24,'Responsible Gaming & Compliance'),
  (25,'Texas Gaming Regulation Overview')
) as c(n, title)
on conflict (course_id, number) do nothing;

-- One lesson per chapter (title mirrors the chapter for the demo outline).
insert into lessons (chapter_id, title, sequence, objectives, estimated_minutes)
select ch.id, ch.title || ' -- Lesson', 1,
       jsonb_build_array('Understand ' || ch.title, 'Demonstrate ' || ch.title),
       45
from chapters ch
where ch.course_id = '00000000-0000-0000-0000-000000000010'
on conflict (chapter_id, sequence) do nothing;

-- A couple of student-visible resources.
insert into resources (owner_type, owner_id, kind, title, url, visibility)
select 'chapter', ch.id, 'flashcards', ch.title || ' Flash Cards',
       'https://decks.tgi.test/ch' || ch.number, 'student'
from chapters ch
where ch.course_id = '00000000-0000-0000-0000-000000000010' and ch.number in (12, 13);

-- ---- Skills + benchmarks (zero-discretion criteria) ------------------------
insert into skills (id, program_id, name, category, sequence) values
  ('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001','TGI Standard Shuffle Sequence','mechanics',1),
  ('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000001','Side Pot Construction','math',2),
  ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000001','Pot Sizing','math',3)
on conflict (id) do nothing;

-- Shuffle: time metric, lower is better (seconds).
insert into skill_benchmarks (skill_id, tier, metric_type, threshold, description, criteria) values
  ('00000000-0000-0000-0000-000000000101','bronze','time', 25, 'Complete shuffle in <= 25s', '{}'),
  ('00000000-0000-0000-0000-000000000101','silver','time', 18, 'Complete shuffle in <= 18s', '{}'),
  ('00000000-0000-0000-0000-000000000101','gold',  'time', 14, 'Complete shuffle in <= 14s', '{}');

-- Side pot: checklist metric (count of required items correct).
insert into skill_benchmarks (skill_id, tier, metric_type, threshold, description, criteria) values
  ('00000000-0000-0000-0000-000000000102','bronze','checklist', 3, '3 of 5 steps correct',
     '{"required":["identify_allin","separate_capped","build_main","build_side","announce"]}'),
  ('00000000-0000-0000-0000-000000000102','silver','checklist', 4, '4 of 5 steps correct',
     '{"required":["identify_allin","separate_capped","build_main","build_side","announce"]}'),
  ('00000000-0000-0000-0000-000000000102','gold',  'checklist', 5, 'All 5 steps correct',
     '{"required":["identify_allin","separate_capped","build_main","build_side","announce"]}');

-- Pot sizing: accuracy metric, higher is better (% correct).
insert into skill_benchmarks (skill_id, tier, metric_type, threshold, description, criteria) values
  ('00000000-0000-0000-0000-000000000103','bronze','accuracy', 80, '>= 80% correct', '{}'),
  ('00000000-0000-0000-0000-000000000103','silver','accuracy', 90, '>= 90% correct', '{}'),
  ('00000000-0000-0000-0000-000000000103','gold',  'accuracy', 98, '>= 98% correct', '{}');

-- ---- Assessments: a chapter-12 quiz + Form A / Form B finals ---------------
insert into assessments (id, program_id, kind, form_code, title, question_count, passing_score, time_limit_minutes, is_secure, max_attempts, randomize_order) values
  ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000001','chapter_quiz', null, 'Chapter 12 Quiz: Pot Management', 3, 70, 15, false, 5, true),
  ('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000001','final_exam',  'A',  'Final Exam -- Form A (Appendix L)', 3, 75, 120, true, 1, false),
  ('00000000-0000-0000-0000-000000000203','00000000-0000-0000-0000-000000000001','final_exam',  'B',  'Final Exam -- Form B (Secure)', 3, 75, 120, true, 1, false)
on conflict (id) do nothing;

-- Questions (correct_answer stays server-side; clients get question_bank_public)
insert into question_bank (id, program_id, chapter_id, stem, type, options, correct_answer, explanation, difficulty)
select
  q.id::uuid, '00000000-0000-0000-0000-000000000001', ch.id, q.stem, q.type,
  q.options::jsonb, q.correct::jsonb, q.expl, 'medium'
from (values
  ('00000000-0000-0000-0000-000000000301', 12,
   'When is a side pot created?', 'multiple_choice',
   '[{"key":"a","text":"Every hand"},{"key":"b","text":"When a player is all-in for less than a call"},{"key":"c","text":"Only in tournaments"}]',
   '"b"', 'A side pot forms when a player is all-in and others continue betting.'),
  ('00000000-0000-0000-0000-000000000302', 12,
   'The main pot can be won by any player still in the hand.', 'true_false',
   '[{"key":"true","text":"True"},{"key":"false","text":"False"}]',
   '"true"', 'All contesting players are eligible for the main pot.'),
  ('00000000-0000-0000-0000-000000000303', 12,
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
