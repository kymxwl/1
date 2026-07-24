-- =============================================================================
-- content/handbook_2026_1.sql
-- The manual's presentational / administrative sections (TGI Manual v1) loaded
-- as program-level resources with inline body text: the TGI Standard, Student
-- Code of Conduct, Professional Standards Oath, Graduation Oath, the Founder's
-- message (student-visible), and the Instructor Evaluation Form + Audition
-- Scorecard (instructor-visible). Idempotent. \ir-included by seed.sql.
-- =============================================================================

\set program_id '''00000000-0000-0000-0000-000000000001'''

insert into resources (id, owner_type, owner_id, kind, title, url, body, visibility)
values
  ('00000000-0000-0000-0000-0000000a0001', 'program', :program_id, 'handout', 'The TGI Standard', null, 'Every Texas Gaming Institute graduate is expected to embody five core principles. These principles define not only how a dealer performs at the table, but how they carry themselves throughout their career.
Protect the Game
Integrity is always the first priority.
Accuracy Before Speed
Fast mistakes are still mistakes.
Professionalism Always
Represent yourself and the industry properly.
Continuous Improvement
Graduation is the beginning of development.
Earn Trust Daily
Trust is built one hand at a time.
Protect the Game. Respect the Players. Uphold the Standard.', 'student'),
  ('00000000-0000-0000-0000-0000000a0002', 'program', :program_id, 'handout', 'Student Code of Conduct', null, 'Students are expected to conduct themselves professionally at all times in any Texas Gaming Institute program or activity. These standards protect the learning environment, the integrity of the certification process, and the reputation of all students.
REQUIRED STUDENT CONDUCT
Arrive on time and prepared for each class session
Treat instructors, staff, and fellow students with respect at all times
Follow all classroom procedures as directed
Maintain professional language and behavior
Handle training equipment and materials with care
Accept instructor feedback professionally and constructively
Conduct yourself in a manner consistent with gaming industry expectations
PROHIBITED CONDUCT
Cheating during drills, exercises, or evaluations of any kind
Harassment, threats, or intimidation directed at any person
Disrupting classroom instruction
Damaging cards, chips, tables, or other training equipment
Use of alcohol or illegal substances during any training activity
Misrepresenting certification status to employers or the public
Participating in poker games, tournaments, sweepstakes machines, or any gaming activity during scheduled class hours
IMPORTANT NOTICE — Gaming During Class Hours
Any student observed participating in poker games, sweepstakes machines, or any gaming activity during scheduled class hours may be removed from the program immediately—without refund, credit, or reinstatement. Texas Gaming Institute reserves the right to dismiss any student whose conduct negatively impacts the learning environment or the integrity of the program.', 'student'),
  ('00000000-0000-0000-0000-0000000a0003', 'program', :program_id, 'handout', 'Professional Standards Oath', null, 'As a student and future gaming professional, I acknowledge that the integrity of the game is my highest responsibility. I understand that every card dealt, every chip handled, and every ruling made contributes to the confidence players place in the game and in the gaming industry as a whole.
I pledge to:
Protect the integrity of every game I deal
Maintain honesty and professionalism in all situations
Treat players, supervisors, and fellow team members with respect
Apply rules fairly and consistently, without bias or favoritism
Continue developing my skills through dedicated study and practice
Report suspicious activity, cheating, theft, or violations of procedure
Place game protection above personal convenience
Strive for accuracy before speed, and professionalism before recognition
I understand that certification represents more than technical ability. It represents trust, responsibility, and a commitment to professional standards.
Student Signature: _________________________________________     Date: _______________
Printed Name: ______________________________________________
SECTION
I
Professional Foundations
The Role, Responsibilities, and Standards of the Professional Dealer
SECTION I — PROFESSIONAL FOUNDATIONS
CHAPTER
1', 'student'),
  ('00000000-0000-0000-0000-0000000a0004', 'program', :program_id, 'handout', 'Graduation Oath', null, '“I understand that every card dealt, every chip handled, and every decision made contributes to the integrity of the game and the confidence players place in the gaming industry. I commit myself to professionalism, honesty, accuracy, and continuous improvement. I will protect the game, respect the players, and uphold the standard.”
Protect the Game. Respect the Players. Uphold the Standard.', 'student'),
  ('00000000-0000-0000-0000-0000000a0005', 'program', :program_id, 'handout', 'Instructor Evaluation Form', null, 'Texas Gaming Institute — Professional Dealer Development Program
Student Name
Date
Instructor
Program Level
Technical Skills
Competency
5
4
3
2
1
Shuffle Sequence
□
□
□
□
□
Card Delivery
□
□
□
□
□
Burn Procedures
□
□
□
□
□
Board Delivery
□
□
□
□
□
Pot Management
□
□
□
□
□
Side Pot Construction
□
□
□
□
□
Hand Reading
□
□
□
□
□
Showdown Procedures
□
□
□
□
□
Scale: 5 = Exceptional, 4 = Meets Standard, 3 = Needs Improvement, 2 = Unsatisfactory, 1 = Fail
Professional Skills
Competency
5
4
3
2
1
Communication
□
□
□
□
□
Professionalism
□
□
□
□
□
Customer Service
□
□
□
□
□
Neutrality
□
□
□
□
□
Game Protection
□
□
□
□
□
Instructor Comments:
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________
Instructor Signature
Date
APPENDIX E', 'instructor'),
  ('00000000-0000-0000-0000-0000000a0006', 'program', :program_id, 'handout', 'TGI Dealer Audition Scorecard', null, 'This scorecard reflects the categories hiring managers typically evaluate during a dealer audition. Use it to self-assess readiness before applying for positions.
Category
Score (1–10)
Notes
Professional Appearance
Table Presence & Confidence
Shuffle Quality & Control
Card Delivery Accuracy
Pot Management
Hand Reading Accuracy
Side Pot Construction
Verbal Procedures & Announcements
Game Protection Awareness
Professionalism Under Pressure
TOTAL SCORE
______ / 100
Hiring Recommendation
Recommendation
Score Range
Select
Immediate Hire
85–100
□
Hire with Additional Training
70–84
□
Future Consideration
55–69
□
Not Recommended at This Time
Below 55
□
APPENDIX G', 'instructor'),
  ('00000000-0000-0000-0000-0000000a0007', 'program', :program_id, 'handout', 'A Message from the Founder', null, 'PERFORMANCE BENCHMARKS
The Texas Gaming Institute benchmark system measures progress across three performance tiers. Students advance from Bronze to Silver to Gold as their speed, accuracy, and consistency improve. Gold represents the audition-ready professional standard.
SKILL
Bronze
Silver
Gold
Full Shuffle
24 sec
22 sec
20 sec
9-Handed Deal
22 sec
20 sec
18 sec
Hand Reading
85%
90%
95%
Side Pots
Pass
Pass
Pass
Showdowns
Pass
Pass
Pass
How Benchmarks Work
Bronze: Competency achieved. The skill is performed correctly and reliably.
Silver: Proficiency achieved. The skill is performed with improved speed and consistency.
Gold: Audition-ready. The skill meets the professional standard expected in a live cardroom.
PROGRAM COMPLETION REQUIREMENTS
To complete the Texas Gaming Institute Professional Dealer Development Program, students must satisfy all of the following:
Complete all required training hours
Pass the written examination
Pass the practical examination with a minimum composite score of 80%
Reach at least the Silver benchmark in all timed and accuracy skills
Demonstrate verified competency in Hold''em, Omaha, Big O (Hi-Lo), Bomb Pots, Pot Management, Side Pot Construction, Hand Reading, Game Protection, and Professional Table Procedures
Maintain attendance at or above 90%
Maintain professional conduct standards throughout the program
Satisfy all instructor completion requirements
Graduate Distinction & Instructor Candidate Status
Graduated with Distinction: Awarded to graduates who achieve 93% or higher on both the written and practical examinations, reach the Gold benchmark in all skills, with no game protection failures and a perfect attendance record.
Instructor Candidate: Awarded at instructor discretion to graduates who demonstrate exceptional mastery and the potential to teach TGI curriculum.
STUDENT CODE OF CONDUCT
Students are expected to conduct themselves professionally at all times in any Texas Gaming Institute program or activity. These standards protect the learning environment, the integrity of the certification process, and the reputation of all students.
REQUIRED STUDENT CONDUCT
Arrive on time and prepared for each class session
Treat instructors, staff, and fellow students with respect at all times
Follow all classroom procedures as directed
Maintain professional language and behavior
Handle training equipment and materials with care
Accept instructor feedback professionally and constructively
Conduct yourself in a manner consistent with gaming industry expectations
PROHIBITED CONDUCT
Cheating during drills, exercises, or evaluations of any kind
Harassment, threats, or intimidation directed at any person
Disrupting classroom instruction
Damaging cards, chips, tables, or other training equipment
Use of alcohol or illegal substances during any training activity
Misrepresenting certification status to employers or the public
Participating in poker games, tournaments, sweepstakes machines, or any gaming activity during scheduled class hours
IMPORTANT NOTICE — Gaming During Class Hours
Any student observed participating in poker games, sweepstakes machines, or any gaming activity during scheduled class hours may be removed from the program immediately—without refund, credit, or reinstatement. Texas Gaming Institute reserves the right to dismiss any student whose conduct negatively impacts the learning environment or the integrity of the program.
PROFESSIONAL STANDARDS OATH
As a student and future gaming professional, I acknowledge that the integrity of the game is my highest responsibility. I understand that every card dealt, every chip handled, and every ruling made contributes to the confidence players place in the game and in the gaming industry as a whole.
I pledge to:
Protect the integrity of every game I deal
Maintain honesty and professionalism in all situations
Treat players, supervisors, and fellow team members with respect
Apply rules fairly and consistently, without bias or favoritism
Continue developing my skills through dedicated study and practice
Report suspicious activity, cheating, theft, or violations of procedure
Place game protection above personal convenience
Strive for accuracy before speed, and professionalism before recognition
I understand that certification represents more than technical ability. It represents trust, responsibility, and a commitment to professional standards.
Student Signature: _________________________________________     Date: _______________
Printed Name: ______________________________________________
SECTION
I
Professional Foundations
The Role, Responsibilities, and Standards of the Professional Dealer
SECTION I — PROFESSIONAL FOUNDATIONS
CHAPTER
1', 'student')
on conflict (id) do update
  set title = excluded.title, body = excluded.body, visibility = excluded.visibility, kind = excluded.kind;
