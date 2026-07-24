-- =============================================================================
-- content/curriculum_2026_1.sql
-- Canonical curriculum for "Professional Poker Dealer" v2026.1.
--
-- Source: TGI Professional Dealer Development Manual v1 (25 chapters in four
-- sections; performance benchmarks; program completion requirements). This is
-- the INSTITUTE'S EDITABLE SOURCE OF TRUTH — program, course, 25 chapters,
-- lessons (objectives drawn from the manual's own subsections), attendance
-- policy, and the skill benchmarks from the manual's Performance Benchmarks
-- table. Idempotent (upserts by key); re-run to update — but only BEFORE a
-- cohort pins the program (the freeze trigger protects it afterward; new
-- content then goes into a new program version).
--
-- Load:  psql "$DATABASE_URL" -f supabase/content/curriculum_2026_1.sql
-- (Also \ir-included by supabase/seed.sql for the demo/local database.)
-- =============================================================================

\set program_id '''00000000-0000-0000-0000-000000000001'''
\set course_id  '''00000000-0000-0000-0000-000000000010'''

insert into programs (id, name, version, total_clock_hours, is_active, effective_date)
values (:program_id, 'Professional Poker Dealer', '2026.1', 100, true, '2026-01-01')
on conflict (id) do update
  set name = excluded.name, total_clock_hours = excluded.total_clock_hours, is_active = excluded.is_active;

insert into attendance_policies (program_id) values (:program_id)
on conflict (program_id) do nothing;

insert into courses (id, program_id, name, sequence, clock_hours)
values (:course_id, :program_id, 'Poker Dealing Core', 1, 100)
on conflict (id) do update set name = excluded.name, clock_hours = excluded.clock_hours;

-- ---- 25 chapters (TGI manual v1). clock_hours sum to 100. --------------------
insert into chapters (course_id, number, title, sequence, clock_hours, manual_page_ref)
values
  (:course_id, 1, 'The Role of the Professional Dealer', 1, 3, 'Manual · Ch 1 (Section I)'),
  (:course_id, 2, 'Professional Conduct & Customer Service', 2, 3, 'Manual · Ch 2 (Section I)'),
  (:course_id, 3, 'Professional Appearance', 3, 2, 'Manual · Ch 3 (Section I)'),
  (:course_id, 4, 'Game Protection Fundamentals', 4, 5, 'Manual · Ch 4 (Section I)'),
  (:course_id, 5, 'Poker Chips & Table Bank Management', 5, 4, 'Manual · Ch 5 (Section I)'),
  (:course_id, 6, 'Cards, Deck Composition & Inspection', 6, 4, 'Manual · Ch 6 (Section I)'),
  (:course_id, 7, 'Washing, Shuffling, Cutting & Deck Control', 7, 6, 'Manual · Ch 7 (Section I)'),
  (:course_id, 8, 'Card Delivery Fundamentals', 8, 5, 'Manual · Ch 8 (Section II)'),
  (:course_id, 9, 'Upcards, Burn Cards & Board Delivery', 9, 5, 'Manual · Ch 9 (Section II)'),
  (:course_id, 10, 'Pot Management & Side Pot Construction', 10, 6, 'Manual · Ch 10 (Section III)'),
  (:course_id, 11, 'Hand Reading Fundamentals', 11, 5, 'Manual · Ch 11 (Section III)'),
  (:course_id, 12, 'Texas Hold''em Procedures', 12, 6, 'Manual · Ch 12 (Section III)'),
  (:course_id, 13, 'No-Limit Hold''em Betting Rules', 13, 4, 'Manual · Ch 13 (Section III)'),
  (:course_id, 14, 'Bomb Pot Procedures', 14, 3, 'Manual · Ch 14 (Section III)'),
  (:course_id, 15, 'Omaha Fundamentals', 15, 5, 'Manual · Ch 15 (Section III)'),
  (:course_id, 16, 'Big O (Hi-Lo) Procedures', 16, 4, 'Manual · Ch 16 (Section III)'),
  (:course_id, 17, 'Advanced Big O: Quartering, Freerolls & Scoops', 17, 3, 'Manual · Ch 17 (Section III)'),
  (:course_id, 18, 'Showdown Procedures', 18, 4, 'Manual · Ch 18 (Section III)'),
  (:course_id, 19, 'Odd Chips & Split Pots', 19, 3, 'Manual · Ch 19 (Section III)'),
  (:course_id, 20, 'Professional Hand Reading Drills', 20, 4, 'Manual · Ch 20 (Section IV)'),
  (:course_id, 21, 'Dealer Auditions & Employment', 21, 3, 'Manual · Ch 21 (Section IV)'),
  (:course_id, 22, 'Professional Development Path', 22, 2, 'Manual · Ch 22 (Section IV)'),
  (:course_id, 23, 'Dealer Relief Procedures', 23, 3, 'Manual · Ch 23 (Section IV)'),
  (:course_id, 24, 'Professional Error Recovery', 24, 4, 'Manual · Ch 24 (Section IV)'),
  (:course_id, 25, 'Final Practical Examination', 25, 4, 'Manual · Ch 25 (Section IV)')
on conflict (course_id, number) do update
  set title = excluded.title, clock_hours = excluded.clock_hours, manual_page_ref = excluded.manual_page_ref;

-- ---- Lessons: a concepts lesson (objectives = manual subsections) + a drill --
insert into lessons (chapter_id, title, sequence, objectives, estimated_minutes)
select ch.id, v.title, v.seq, v.objectives::jsonb, v.mins
from chapters ch join (values
  (1, 'The Role of the Professional Dealer — Standards & Procedure', 1, '["Explain: Overview", "Explain: Primary Responsibilities", "Explain: The Dealer''s First Priority", "Explain: Professional Standards"]', 60),
  (1, 'The Role of the Professional Dealer — Table Drill', 2, '["Perform The Role of the Professional Dealer to the TGI benchmark", "Sustain The Role of the Professional Dealer at live-game pace"]', 120),
  (2, 'Professional Conduct & Customer Service — Standards & Procedure', 1, '["Explain: Why Professionalism Matters", "Explain: Dealer Neutrality", "Explain: Prohibited Commentary", "Explain: Handling Difficult Players"]', 60),
  (2, 'Professional Conduct & Customer Service — Table Drill', 2, '["Perform Professional Conduct & Customer Service to the TGI benchmark", "Sustain Professional Conduct & Customer Service at live-game pace"]', 120),
  (3, 'Professional Appearance — Standards & Procedure', 1, '["Explain: Why Appearance Matters", "Explain: Required Standards", "Explain: Prohibited", "Explain: Appearance as a Daily Habit"]', 60),
  (3, 'Professional Appearance — Table Drill', 2, '["Perform Professional Appearance to the TGI benchmark", "Sustain Professional Appearance at live-game pace"]', 120),
  (4, 'Game Protection Fundamentals — Standards & Procedure', 1, '["Explain: What Is Game Protection?", "Explain: The Dealer as First Line of Defense", "Explain: Areas Requiring Active Protection", "Explain: When to Call a Supervisor"]', 60),
  (4, 'Game Protection Fundamentals — Table Drill', 2, '["Perform Game Protection Fundamentals to the TGI benchmark", "Sustain Game Protection Fundamentals at live-game pace"]', 120),
  (5, 'Poker Chips & Table Bank Management — Standards & Procedure', 1, '["Explain: Table Bank Organization", "Explain: Chip Cutting Standards", "Explain: Selling Chips", "Explain: Making Change"]', 60),
  (5, 'Poker Chips & Table Bank Management — Table Drill', 2, '["Perform Poker Chips & Table Bank Management to the TGI benchmark", "Sustain Poker Chips & Table Bank Management at live-game pace"]', 120),
  (6, 'Cards, Deck Composition & Inspection — Standards & Procedure', 1, '["Explain: Standard Deck Composition", "Explain: New Deck Inspection", "Explain: Common Deck Defects"]', 60),
  (6, 'Cards, Deck Composition & Inspection — Table Drill', 2, '["Perform Cards, Deck Composition & Inspection to the TGI benchmark", "Sustain Cards, Deck Composition & Inspection at live-game pace"]', 120),
  (7, 'Washing, Shuffling, Cutting & Deck Control — Standards & Procedure', 1, '["Explain: Washing the Cards", "Explain: The TGI Standard Shuffle Sequence", "Explain: Riffle Technique Fundamentals", "Explain: Cutting & Deck Control"]', 60),
  (7, 'Washing, Shuffling, Cutting & Deck Control — Table Drill', 2, '["Perform Washing, Shuffling, Cutting & Deck Control to the TGI benchmark", "Sustain Washing, Shuffling, Cutting & Deck Control at live-game pace"]', 120),
  (8, 'Card Delivery Fundamentals — Standards & Procedure', 1, '["Explain: Philosophy of Card Delivery", "Explain: Downcard Delivery Standards", "Explain: Body Positioning", "Explain: Seat Progression for Training"]', 60),
  (8, 'Card Delivery Fundamentals — Table Drill', 2, '["Perform Card Delivery Fundamentals to the TGI benchmark", "Sustain Card Delivery Fundamentals at live-game pace"]', 120),
  (9, 'Upcards, Burn Cards & Board Delivery — Standards & Procedure', 1, '["Explain: Professional Board Presentation", "Explain: Burn Cards", "Explain: Delivering the Flop, Turn & River", "Explain: Board Placement Standards"]', 60),
  (9, 'Upcards, Burn Cards & Board Delivery — Table Drill', 2, '["Perform Upcards, Burn Cards & Board Delivery to the TGI benchmark", "Sustain Upcards, Burn Cards & Board Delivery at live-game pace"]', 120),
  (10, 'Pot Management & Side Pot Construction — Standards & Procedure', 1, '["Explain: Pot Awareness", "Explain: Building the Pot", "Explain: Side Pot Fundamentals", "Explain: Common Side Pot Mistakes"]', 60),
  (10, 'Pot Management & Side Pot Construction — Table Drill', 2, '["Perform Pot Management & Side Pot Construction to the TGI benchmark", "Sustain Pot Management & Side Pot Construction at live-game pace"]', 120),
  (11, 'Hand Reading Fundamentals — Standards & Procedure', 1, '["Explain: Cards Speak", "Explain: Standard Hand Rankings", "Explain: Kickers", "Explain: Dealer Responsibilities at Showdown"]', 60),
  (11, 'Hand Reading Fundamentals — Table Drill', 2, '["Perform Hand Reading Fundamentals to the TGI benchmark", "Sustain Hand Reading Fundamentals at live-game pace"]', 120),
  (12, 'Texas Hold''em Procedures — Standards & Procedure', 1, '["Explain: Game Structure", "Explain: Complete Hand Sequence", "Explain: The Dealer Button", "Explain: Blind Structure & The Option"]', 60),
  (12, 'Texas Hold''em Procedures — Table Drill', 2, '["Perform Texas Hold''em Procedures to the TGI benchmark", "Sustain Texas Hold''em Procedures at live-game pace"]', 120),
  (13, 'No-Limit Hold''em Betting Rules — Standards & Procedure', 1, '["Explain: Verbal Is Binding", "Explain: Legal Raise Requirements", "Explain: The Oversized Chip Rule", "Explain: String Bets and String Raises"]', 60),
  (13, 'No-Limit Hold''em Betting Rules — Table Drill', 2, '["Perform No-Limit Hold''em Betting Rules to the TGI benchmark", "Sustain No-Limit Hold''em Betting Rules at live-game pace"]', 120),
  (14, 'Bomb Pot Procedures — Standards & Procedure', 1, '["Explain: What Is a Bomb Pot?", "Explain: Standard Hold''em Bomb Pot Procedure", "Explain: Double-Board Bomb Pots", "Explain: Why Bomb Pots Are Challenging"]', 60),
  (14, 'Bomb Pot Procedures — Table Drill', 2, '["Perform Bomb Pot Procedures to the TGI benchmark", "Sustain Bomb Pot Procedures at live-game pace"]', 120),
  (15, 'Omaha Fundamentals — Standards & Procedure', 1, '["Explain: The Two-Card Rule", "Explain: Omaha Hand Reading Process", "Explain: Common Omaha Errors"]', 60),
  (15, 'Omaha Fundamentals — Table Drill', 2, '["Perform Omaha Fundamentals to the TGI benchmark", "Sustain Omaha Fundamentals at live-game pace"]', 120),
  (16, 'Big O (Hi-Lo) Procedures — Standards & Procedure', 1, '["Explain: Qualifying Low Hands", "Explain: Reading Low Hands", "Explain: The Wheel", "Explain: Pot Splitting"]', 60),
  (16, 'Big O (Hi-Lo) Procedures — Table Drill', 2, '["Perform Big O (Hi-Lo) Procedures to the TGI benchmark", "Sustain Big O (Hi-Lo) Procedures at live-game pace"]', 120),
  (17, 'Advanced Big O: Quartering, Freerolls & Scoops — Standards & Procedure', 1, '["Explain: Scooping", "Explain: Quartering", "Explain: Freerolls", "Explain: Three-Way Splits"]', 60),
  (17, 'Advanced Big O: Quartering, Freerolls & Scoops — Table Drill', 2, '["Perform Advanced Big O: Quartering, Freerolls & Scoops to the TGI benchmark", "Sustain Advanced Big O: Quartering, Freerolls & Scoops at live-game pace"]', 120),
  (18, 'Showdown Procedures — Standards & Procedure', 1, '["Explain: Initiating Showdown", "Explain: Reading and Announcing Hands", "Explain: Exposing Hands", "Explain: Killing Losing Hands"]', 60),
  (18, 'Showdown Procedures — Table Drill', 2, '["Perform Showdown Procedures to the TGI benchmark", "Sustain Showdown Procedures at live-game pace"]', 120),
  (19, 'Odd Chips & Split Pots — Standards & Procedure', 1, '["Explain: Odd Chips in Hold''em", "Explain: Odd Chips in Split-Pot Games", "Explain: Quartered Pot Calculations", "Explain: Three-Way Equal Splits"]', 60),
  (19, 'Odd Chips & Split Pots — Table Drill', 2, '["Perform Odd Chips & Split Pots to the TGI benchmark", "Sustain Odd Chips & Split Pots at live-game pace"]', 120),
  (20, 'Professional Hand Reading Drills — Standards & Procedure', 1, '["Explain: Lock Hand Recognition", "Explain: Drill 1 \u2014 Rank Recognition", "Explain: Drill 2 \u2014 Board Pattern Recognition", "Explain: Drill 3 \u2014 Winner Identification"]', 60),
  (20, 'Professional Hand Reading Drills — Table Drill', 2, '["Perform Professional Hand Reading Drills to the TGI benchmark", "Sustain Professional Hand Reading Drills at live-game pace"]', 120),
  (21, 'Dealer Auditions & Employment — Standards & Procedure', 1, '["Explain: What Employers Actually Evaluate", "Explain: The Dealer Audition Process", "Explain: Professional Appearance at the Audition", "Explain: Table Presence"]', 60),
  (21, 'Dealer Auditions & Employment — Table Drill', 2, '["Perform Dealer Auditions & Employment to the TGI benchmark", "Sustain Dealer Auditions & Employment at live-game pace"]', 120),
  (22, 'Professional Development Path — Standards & Procedure', 1, '["Explain: A Career, Not Just a Job", "Explain: The Path", "Explain: Advancing at Every Stage"]', 60),
  (22, 'Professional Development Path — Table Drill', 2, '["Perform Professional Development Path to the TGI benchmark", "Sustain Professional Development Path at live-game pace"]', 120),
  (23, 'Dealer Relief Procedures — Standards & Procedure', 1, '["Explain: Incoming Dealer Responsibilities", "Explain: Bank Verification", "Explain: Outgoing Dealer Responsibilities"]', 60),
  (23, 'Dealer Relief Procedures — Table Drill', 2, '["Perform Dealer Relief Procedures to the TGI benchmark", "Sustain Dealer Relief Procedures at live-game pace"]', 120),
  (24, 'Professional Error Recovery — Standards & Procedure', 1, '["Explain: Common Dealing Errors", "Explain: The Four-Step Recovery Model", "Explain: Misdeals", "Explain: Incorrect Payouts"]', 60),
  (24, 'Professional Error Recovery — Table Drill', 2, '["Perform Professional Error Recovery to the TGI benchmark", "Sustain Professional Error Recovery at live-game pace"]', 120),
  (25, 'Final Practical Examination — Standards & Procedure', 1, '["Explain: Evaluation Categories", "Explain: Scoring Scale", "Explain: Automatic Failure Conditions"]', 60),
  (25, 'Final Practical Examination — Table Drill', 2, '["Perform Final Practical Examination to the TGI benchmark", "Sustain Final Practical Examination at live-game pace"]', 120)
) as v(chapter_number, title, seq, objectives, mins)
  on ch.number = v.chapter_number
where ch.course_id = :course_id
on conflict (chapter_id, sequence) do update
  set title = excluded.title, objectives = excluded.objectives, estimated_minutes = excluded.estimated_minutes;

-- ---- Skills & benchmarks (TGI manual Performance Benchmarks table) -----------
-- Bronze = competency · Silver = proficiency · Gold = audition-ready.
insert into skills (id, program_id, name, category, sequence) values
  ('00000000-0000-0000-0000-000000000101', :program_id, 'Full Shuffle',            'mechanics', 1),
  ('00000000-0000-0000-0000-000000000102', :program_id, '9-Handed Deal',           'mechanics', 2),
  ('00000000-0000-0000-0000-000000000103', :program_id, 'Hand Reading',            'knowledge', 3),
  ('00000000-0000-0000-0000-000000000104', :program_id, 'Side Pot Construction',   'math',      4),
  ('00000000-0000-0000-0000-000000000105', :program_id, 'Showdowns',               'procedure', 5)
on conflict (id) do update set name = excluded.name, category = excluded.category, sequence = excluded.sequence;

-- Full Shuffle & 9-Handed Deal: time (seconds, lower is better).
insert into skill_benchmarks (skill_id, tier, metric_type, threshold, description, criteria) values
  ('00000000-0000-0000-0000-000000000101','bronze','time',24,'Full shuffle in <= 24s','{}'),
  ('00000000-0000-0000-0000-000000000101','silver','time',22,'Full shuffle in <= 22s','{}'),
  ('00000000-0000-0000-0000-000000000101','gold',  'time',20,'Full shuffle in <= 20s (audition-ready)','{}'),
  ('00000000-0000-0000-0000-000000000102','bronze','time',22,'9-handed deal in <= 22s','{}'),
  ('00000000-0000-0000-0000-000000000102','silver','time',20,'9-handed deal in <= 20s','{}'),
  ('00000000-0000-0000-0000-000000000102','gold',  'time',18,'9-handed deal in <= 18s (audition-ready)','{}')
on conflict (skill_id, tier) do update
  set metric_type = excluded.metric_type, threshold = excluded.threshold, description = excluded.description, criteria = excluded.criteria;

-- Hand Reading: accuracy (%, higher is better).
insert into skill_benchmarks (skill_id, tier, metric_type, threshold, description, criteria) values
  ('00000000-0000-0000-0000-000000000103','bronze','accuracy',85,'>= 85% correct','{}'),
  ('00000000-0000-0000-0000-000000000103','silver','accuracy',90,'>= 90% correct','{}'),
  ('00000000-0000-0000-0000-000000000103','gold',  'accuracy',95,'>= 95% correct (audition-ready)','{}')
on conflict (skill_id, tier) do update
  set metric_type = excluded.metric_type, threshold = excluded.threshold, description = excluded.description, criteria = excluded.criteria;

-- Side Pots & Showdowns: pass/fail checklist. The manual scores these Pass at
-- every tier; a correct performance meets the audition (Gold) standard.
insert into skill_benchmarks (skill_id, tier, metric_type, threshold, description, criteria) values
  ('00000000-0000-0000-0000-000000000104','bronze','checklist',4,'All required side-pot steps correct','{"required":["identify_allin","separate_capped","build_main","build_side"]}'),
  ('00000000-0000-0000-0000-000000000104','silver','checklist',4,'All required side-pot steps correct','{"required":["identify_allin","separate_capped","build_main","build_side"]}'),
  ('00000000-0000-0000-0000-000000000104','gold',  'checklist',4,'All required side-pot steps correct (Pass)','{"required":["identify_allin","separate_capped","build_main","build_side"]}'),
  ('00000000-0000-0000-0000-000000000105','bronze','checklist',4,'All required showdown steps correct','{"required":["initiate","read_announce","expose","kill_losing"]}'),
  ('00000000-0000-0000-0000-000000000105','silver','checklist',4,'All required showdown steps correct','{"required":["initiate","read_announce","expose","kill_losing"]}'),
  ('00000000-0000-0000-0000-000000000105','gold',  'checklist',4,'All required showdown steps correct (Pass)','{"required":["initiate","read_announce","expose","kill_losing"]}')
on conflict (skill_id, tier) do update
  set metric_type = excluded.metric_type, threshold = excluded.threshold, description = excluded.description, criteria = excluded.criteria;
