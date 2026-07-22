-- =============================================================================
-- content/curriculum_2026_1.sql
-- Canonical curriculum content for "Professional Poker Dealer" v2026.1.
--
-- This is the INSTITUTE'S EDITABLE SOURCE OF TRUTH for the 25-chapter program:
-- program + course + 25 chapters + lessons (with objectives) + attendance
-- policy. It is idempotent (upserts by program/course/chapter/lesson keys), so
-- editing a title, clock-hour value, or objective here and re-running updates
-- the program in place.
--
-- MUST be loaded BEFORE any cohort is pinned to the program — once a cohort
-- exists, the curriculum-freeze trigger (correctly) blocks structural edits, and
-- new content must go into a NEW program version (e.g. content/curriculum_2027_1).
--
-- Load standalone:   psql "$DATABASE_URL" -f supabase/content/curriculum_2026_1.sql
-- Or it is included by supabase/seed.sql for the demo/local database.
--
-- Chapter clock hours are metadata for the outline; the regulatory total is
-- programs.total_clock_hours (100). Content marked "[verify vs manual]" is a
-- professional starting structure to be confirmed against the TGI manual.
-- =============================================================================

\set program_id '''00000000-0000-0000-0000-000000000001'''
\set course_id  '''00000000-0000-0000-0000-000000000010'''

-- Program (version-pinned).
insert into programs (id, name, version, total_clock_hours, is_active, effective_date)
values (:program_id, 'Professional Poker Dealer', '2026.1', 100, true, '2026-01-01')
on conflict (id) do update
  set name = excluded.name,
      total_clock_hours = excluded.total_clock_hours,
      is_active = excluded.is_active;

-- Attendance policy (resolved decisions; see docs/DECISIONS.md — ratify w/ TWC).
insert into attendance_policies (program_id) values (:program_id)
on conflict (program_id) do nothing;

-- Course.
insert into courses (id, program_id, name, sequence, clock_hours)
values (:course_id, :program_id, 'Poker Dealing Core', 1, 100)
on conflict (id) do update set name = excluded.name, clock_hours = excluded.clock_hours;

-- ---- 25 chapters -----------------------------------------------------------
-- (number, title, clock_hours, manual_page_ref). Sum of clock_hours = 100.
insert into chapters (course_id, number, title, sequence, clock_hours, manual_page_ref)
select :course_id, c.n, c.title, c.n, c.hrs, c.pages
from (values
  ( 1,'Table Setup & Chip Handling',                 4,'Manual §1 · pp. 1-14'),
  ( 2,'The Deck: Inspection, Wash & Verification',   4,'Manual §2 · pp. 15-26'),
  ( 3,'Standard Shuffle Sequence',                   5,'Manual §3 · pp. 27-40'),
  ( 4,'The Riffle, Strip & Box',                     4,'Manual §4 · pp. 41-52'),
  ( 5,'Cutting the Deck & The Cut Card',             4,'Manual §5 · pp. 53-60'),
  ( 6,'Pitching Cards & Delivery Mechanics',         5,'Manual §6 · pp. 61-76'),
  ( 7,'Reading the Board & Hand Rankings',           4,'Manual §7 · pp. 77-90'),
  ( 8,'Texas Hold''em Dealing Procedure',            5,'Manual §8 · pp. 91-108'),
  ( 9,'Omaha Dealing Procedure',                     4,'Manual §9 · pp. 109-122'),
  (10,'Seven-Card Stud Procedure',                   4,'Manual §10 · pp. 123-136'),
  (11,'Managing the Button & Blinds',                4,'Manual §11 · pp. 137-148'),
  (12,'Pot Management & Pot Sizing',                 4,'Manual §12 · pp. 149-162'),
  (13,'Side Pot Construction',                       4,'Manual §13 · pp. 163-176'),
  (14,'Collecting the Rake & Drop',                  4,'Manual §14 · pp. 177-186'),
  (15,'Awarding the Pot & Odd Chips',                4,'Manual §15 · pp. 187-198'),
  (16,'Handling All-In Situations',                  4,'Manual §16 · pp. 199-212'),
  (17,'Splitting Pots & Chopping',                   3,'Manual §17 · pp. 213-222'),
  (18,'Tournament Dealing Fundamentals',             4,'Manual §18 · pp. 223-236'),
  (19,'Blind Structures & Clock Management',         4,'Manual §19 · pp. 237-248'),
  (20,'Chip Race & Color-Up Procedure',              4,'Manual §20 · pp. 249-260'),
  (21,'Player Etiquette & Table Control',            4,'Manual §21 · pp. 261-274'),
  (22,'Handling Disputes & Floor Calls',             4,'Manual §22 · pp. 275-288'),
  (23,'Irregularities, Misdeals & Penalties',        4,'Manual §23 · pp. 289-302'),
  (24,'Responsible Gaming & Compliance',             3,'Manual §24 · pp. 303-312'),
  (25,'Texas Gaming Regulation Overview',            3,'Manual §25 · pp. 313-324')
) as c(n, title, hrs, pages)
on conflict (course_id, number) do update
  set title = excluded.title,
      clock_hours = excluded.clock_hours,
      manual_page_ref = excluded.manual_page_ref;

-- ---- Lessons: two per chapter (classroom + table drill), with objectives ----
insert into lessons (chapter_id, title, sequence, objectives, estimated_minutes)
select ch.id, l.title, l.seq, l.objectives, l.mins
from chapters ch
cross join lateral (values
  (
    ch.title || ' — Standards & Procedure', 1,
    jsonb_build_array(
      'State the TGI standard procedure for ' || ch.title,
      'Recognize and name common errors in ' || ch.title
    ), 60
  ),
  (
    ch.title || ' — Table Drill', 2,
    jsonb_build_array(
      'Perform ' || ch.title || ' to the TGI benchmark',
      'Sustain ' || ch.title || ' at live-game pace'
    ), 120
  )
) as l(title, seq, objectives, mins)
where ch.course_id = :course_id
on conflict (chapter_id, sequence) do update
  set title = excluded.title,
      objectives = excluded.objectives,
      estimated_minutes = excluded.estimated_minutes;
