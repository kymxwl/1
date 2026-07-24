-- =============================================================================
-- content/reference_2026_1.sql
-- Appendix A (Poker Terminology Glossary) + Appendix B (TGI Quick Reference
-- Charts), from TGI Manual v1, loaded as study flashcards.
--   * Glossary: term -> definition, under Ch 1 (foundations) as a "Terminology"
--     deck.
--   * Quick-reference charts: one reference card each (Hand Rankings, Critical
--     Rules, Performance Standards, Shuffle Sequence, Dealer Priority Order),
--     each filed under its natural chapter.
-- Idempotent (deterministic ids). \ir-included by seed.sql.
-- =============================================================================

\set course_id '''00000000-0000-0000-0000-000000000010'''

-- Glossary terms -> flashcards (Ch 1).
insert into flashcards (id, chapter_id, front, back, sequence, is_active)
select v.id::uuid, ch.id, v.front, v.back, v.seq, true
from (values
  ('00000000-0000-0000-0000-0000000b0001', '[Glossary] Action', 'A player''s decision during a betting round: check, bet, call, raise, or fold.', 101),
  ('00000000-0000-0000-0000-0000000b0002', '[Glossary] Aggressive Action', 'Any wager that may immediately win the pot (a bet or a raise).', 102),
  ('00000000-0000-0000-0000-0000000b0003', '[Glossary] All-In', 'A wager committing all of a player''s remaining chips to the pot.', 103),
  ('00000000-0000-0000-0000-0000000b0004', '[Glossary] Angle Shooting', 'Using technically legal actions to intentionally create confusion or gain unfair advantage.', 104),
  ('00000000-0000-0000-0000-0000000b0005', '[Glossary] Ante', 'A forced wager contributed by all players before cards are dealt.', 105),
  ('00000000-0000-0000-0000-0000000b0006', '[Glossary] Board', 'The community cards visible to all players in the center of the table.', 106),
  ('00000000-0000-0000-0000-0000000b0007', '[Glossary] Burn Card', 'The top card removed from the deck before each set of community cards is dealt.', 107),
  ('00000000-0000-0000-0000-0000000b0008', '[Glossary] Cards Speak', 'The principle that the actual cards determine the winner, regardless of player declarations.', 108),
  ('00000000-0000-0000-0000-0000000b0009', '[Glossary] Cut Card', 'A solid plastic card used to cut the deck and protect the bottom card from exposure.', 109),
  ('00000000-0000-0000-0000-0000000b0010', '[Glossary] Deuce', 'Industry term for the 2 card.', 110),
  ('00000000-0000-0000-0000-0000000b0011', '[Glossary] Freeroll', 'A situation where a player cannot lose a portion of the pot but may win additional portions.', 111),
  ('00000000-0000-0000-0000-0000000b0012', '[Glossary] Lock Hand', 'A hand that cannot be beaten given the current board.', 112),
  ('00000000-0000-0000-0000-0000000b0013', '[Glossary] Muck', 'The pile of dead and discarded cards.', 113),
  ('00000000-0000-0000-0000-0000000b0014', '[Glossary] Quartered', 'Receiving one-quarter of the total pot in a split-pot game.', 114),
  ('00000000-0000-0000-0000-0000000b0015', '[Glossary] Scoop', 'Winning both the high and low halves of a split-pot game.', 115),
  ('00000000-0000-0000-0000-0000000b0016', '[Glossary] Side Pot', 'A separate pot created when one or more players are all-in for different amounts.', 116),
  ('00000000-0000-0000-0000-0000000b0017', '[Glossary] String Raise', 'An illegal raise completed in multiple motions without a prior verbal declaration.', 117),
  ('00000000-0000-0000-0000-0000000b0018', '[Glossary] Stub', 'The remaining undealt portion of the deck after cards have been distributed.', 118),
  ('00000000-0000-0000-0000-0000000b0019', '[Glossary] Table Stakes', 'A rule limiting players to wagering only chips in play at the start of a hand.', 119),
  ('00000000-0000-0000-0000-0000000b0020', '[Glossary] Trey', 'Industry term for the 3 card.', 120),
  ('00000000-0000-0000-0000-0000000b0021', '[Glossary] The Wheel', 'A-2-3-4-5; the best possible low hand in Hi-Lo games.', 121)
) as v(id, front, back, seq)
cross join (select id from chapters where number = 1 and course_id = :course_id) ch
on conflict (id) do update set front=excluded.front, back=excluded.back, sequence=excluded.sequence, chapter_id=excluded.chapter_id;

-- Quick-reference chart(s) for Ch 11
insert into flashcards (id, chapter_id, front, back, sequence, is_active)
select v.id::uuid, ch.id, v.front, v.back, v.seq, true
from (values
  ('00000000-0000-0000-0000-0000000b0901', '[Quick Reference] Hand Rankings', 'Rank · Hand
1 (Best) — Royal Flush
2 — Straight Flush
3 — Four of a Kind
4 — Full House
5 — Flush
6 — Straight
7 — Three of a Kind
8 — Two Pair
9 — One Pair
10 (Lowest) — High Card', 901)
) as v(id, front, back, seq)
cross join (select id from chapters where number = 11 and course_id = :course_id) ch
on conflict (id) do update set front=excluded.front, back=excluded.back, sequence=excluded.sequence, chapter_id=excluded.chapter_id;

-- Quick-reference chart(s) for Ch 13
insert into flashcards (id, chapter_id, front, back, sequence, is_active)
select v.id::uuid, ch.id, v.front, v.back, v.seq, true
from (values
  ('00000000-0000-0000-0000-0000000b0902', '[Quick Reference] Critical Rules at a Glance', 'Rule · Standard
Omaha: Hole Cards Required — Exactly 2 hole cards; exactly 3 board cards.
Big O: Low Qualifier — Five different cards, all eight or lower. Ace plays low.
Odd Chip — Hold''em — First tied player clockwise from the button.
Odd Chip — Split-Pot Games — Goes to the HIGH side first.
Oversized Chip Rule — Single chip placed silently against a bet = call only.
Verbal Is Binding — A clear verbal declaration during a player''s turn is binding.
String Bet — Multiple chip motions without a prior verbal declaration = illegal.', 902)
) as v(id, front, back, seq)
cross join (select id from chapters where number = 13 and course_id = :course_id) ch
on conflict (id) do update set front=excluded.front, back=excluded.back, sequence=excluded.sequence, chapter_id=excluded.chapter_id;

-- Quick-reference chart(s) for Ch 25
insert into flashcards (id, chapter_id, front, back, sequence, is_active)
select v.id::uuid, ch.id, v.front, v.back, v.seq, true
from (values
  ('00000000-0000-0000-0000-0000000b0903', '[Quick Reference] TGI Performance Standards', 'Skill · Standard
Full Shuffle Sequence — Under 20 seconds
9-Handed Hold''em Deal — Under 18 seconds
Pot Calculation Accuracy — 95% minimum
Side Pot Construction Accuracy — 100% required
Hand Reading Accuracy — 95% minimum
Final Practical Examination — 80% minimum composite
Attendance Requirement — 90% minimum', 903)
) as v(id, front, back, seq)
cross join (select id from chapters where number = 25 and course_id = :course_id) ch
on conflict (id) do update set front=excluded.front, back=excluded.back, sequence=excluded.sequence, chapter_id=excluded.chapter_id;

-- Quick-reference chart(s) for Ch 7
insert into flashcards (id, chapter_id, front, back, sequence, is_active)
select v.id::uuid, ch.id, v.front, v.back, v.seq, true
from (values
  ('00000000-0000-0000-0000-0000000b0904', '[Quick Reference] TGI Shuffle Sequence', 'Step · Action
1 — Riffle Shuffle
2 — Riffle Shuffle
3 — Box
4 — Riffle Shuffle
5 — Cut', 904)
) as v(id, front, back, seq)
cross join (select id from chapters where number = 7 and course_id = :course_id) ch
on conflict (id) do update set front=excluded.front, back=excluded.back, sequence=excluded.sequence, chapter_id=excluded.chapter_id;

-- Quick-reference chart(s) for Ch 1
insert into flashcards (id, chapter_id, front, back, sequence, is_active)
select v.id::uuid, ch.id, v.front, v.back, v.seq, true
from (values
  ('00000000-0000-0000-0000-0000000b0905', '[Quick Reference] Dealer Priority Order', 'Priority · Responsibility
1 — Protect the game
2 — Protect the pot
3 — Protect the deck
4 — Protect the muck
5 — Protect the players
Speed is never Priority #1. — APPENDIX C', 905)
) as v(id, front, back, seq)
cross join (select id from chapters where number = 1 and course_id = :course_id) ch
on conflict (id) do update set front=excluded.front, back=excluded.back, sequence=excluded.sequence, chapter_id=excluded.chapter_id;

