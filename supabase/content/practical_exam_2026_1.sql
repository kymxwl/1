-- =============================================================================
-- content/practical_exam_2026_1.sql
-- Ch 25 Final Practical Examination instrument (TGI Manual v1): the secure
-- final_practical assessment + its nine evaluation categories with passing
-- standards. Idempotent. \ir-included by seed.sql; load standalone with:
--   psql "$DATABASE_URL" -f supabase/content/practical_exam_2026_1.sql
-- =============================================================================

\set program_id '''00000000-0000-0000-0000-000000000001'''

-- The practical final. Composite >= 80% to graduate (per the manual).
insert into assessments (id, program_id, kind, form_code, title, question_count, passing_score, time_limit_minutes, is_secure, max_attempts, randomize_order)
values ('00000000-0000-0000-0000-000000000205', :program_id, 'final_practical', null,
        'Final Practical Examination (Ch 25)', 0, 80, null, true, 2, false)
on conflict (id) do update
  set title = excluded.title, passing_score = excluded.passing_score,
      is_secure = excluded.is_secure, max_attempts = excluded.max_attempts;

-- The nine evaluation categories (scored 1..5; 5 = Exceptional, 1 = Fail).
insert into practical_categories (program_id, key, name, standard, sequence)
values
  (:program_id, 'shuffle_deck_control',  'Shuffle Sequence & Deck Control', 'Under 20 seconds; proper technique', 1),
  (:program_id, 'card_delivery',         'Card Delivery',                   'Accurate, controlled, and consistent', 2),
  (:program_id, 'pot_management',        'Pot Management',                  '95% accuracy minimum', 3),
  (:program_id, 'side_pot_construction', 'Side Pot Construction',           '100% accuracy required', 4),
  (:program_id, 'hand_reading',          'Hand Reading',                    '95% accuracy minimum', 5),
  (:program_id, 'showdown',              'Showdown Procedures',             'Pass/Fail', 6),
  (:program_id, 'game_protection',       'Game Protection',                 'Pass/Fail', 7),
  (:program_id, 'professional_conduct',  'Professional Conduct',            'Pass/Fail', 8),
  (:program_id, 'customer_service',      'Customer Service',                'Pass/Fail', 9)
on conflict (program_id, key) do update
  set name = excluded.name, standard = excluded.standard, sequence = excluded.sequence;
