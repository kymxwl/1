# TGI Learning Management System — Data Model & Module Spec

**Target repo:** `tgi-app` (React Native / Expo SDK 54, Supabase backend)
**Approach:** Extend the existing schema. Do not create a separate application or a second student table.
**Status:** Draft for review. Nothing here is implemented yet.

---

## 0. Governing Principles

These constrain every decision below. Where an implementation choice is ambiguous, resolve it in favor of the principle.

1. **One student identity.** The LMS reuses the existing auth and student records. A student who signs the enrollment packet and pays is the same row that accrues clock hours and receives a certificate. No reconciliation between systems.
2. **Records TWC may inspect are append-only.** Attendance, assessment attempts, skill evaluations, and completion records are never updated in place and never hard-deleted. Corrections are new rows that supersede prior rows, with a reason and an actor.
3. **Zero discretion at decision points.** Passing, tier assignment, and Distinction are *computed* from stored data by deterministic rules. No field anywhere lets a human type in a final outcome directly.
4. **Answer keys never reach the client.** Assessment grading happens server-side. The app receives questions without correct-answer fields, submits responses, and receives a score.
5. **Clock hours are the regulatory unit.** The program is 100 clock hours. Everything about scheduling and attendance is designed to produce a defensible clock-hour ledger, not just a "percent complete" bar.

---

## 1. Scope

### In scope (v1)
- Curriculum structure: program → course → chapter → lesson
- Cohort scheduling and session calendar
- Attendance capture and the clock-hour ledger
- Quiz bank, chapter quizzes, flash cards
- Secure written exams (Appendix L, Form B) with form selection and server-side grading
- Practical skill evaluation against Bronze / Silver / Gold benchmarks
- Student progress view (the student-facing Dealer Passport surface)
- Instructor console: take attendance, score practicals, review quiz results
- Admin reporting: attendance registers, grade rosters, completion records

### Out of scope (v1)
- Discussion forums, messaging, peer interaction
- Video hosting (link out to existing hosting; store the URL only)
- Payment or refund logic (already exists — `calc_refund()`, Stripe links)
- Public course catalog / self-serve enrollment (intake flow already exists)

---

## 2. Data Model

Table names assume the LMS lives alongside existing tables. Prefix with `lms_` where a name might collide.

### 2.1 Curriculum

**`programs`**
| column | type | notes |
|---|---|---|
| id | uuid pk | |
| name | text | e.g. "Professional Poker Dealer" |
| version | text | e.g. "2026.1" — see versioning note below |
| total_clock_hours | numeric | 100 |
| is_active | bool | |
| effective_date | date | |

**`courses`** — a program contains one or more courses.
`id`, `program_id fk`, `name`, `sequence`, `clock_hours`

**`chapters`** — maps to the 25 manual chapters.
`id`, `course_id fk`, `number`, `title`, `sequence`, `clock_hours`, `manual_page_ref`

**`lessons`** — the teachable unit inside a chapter.
`id`, `chapter_id fk`, `title`, `sequence`, `objectives jsonb`, `lecture_deck_url`, `instructor_notes_url`, `estimated_minutes`

**`resources`** — flash card sets, handouts, video links, deck files.
`id`, `owner_type` (`program`|`course`|`chapter`|`lesson`), `owner_id`, `kind` (`deck`|`flashcards`|`video`|`handout`|`manual`), `title`, `url`, `visibility` (`student`|`instructor`|`admin`)

> **Versioning note.** Curriculum is versioned at the `programs` level. A cohort is pinned to one `program_id` at creation and never migrates. This is what lets you answer "what exactly was this graduate taught" years later.

### 2.2 Cohorts & Enrollment

**`cohorts`**
`id`, `program_id fk`, `name` (e.g. "2026-A"), `start_date`, `end_date`, `instructor_id fk`, `capacity`, `status` (`planned`|`active`|`completed`|`cancelled`), `location`

**`enrollments`** — links an existing student to a cohort.
`id`, `student_id fk`, `cohort_id fk`, `enrolled_at`, `status` (`enrolled`|`active`|`withdrawn`|`completed`|`terminated`), `status_reason`, `tuition_rate` (`standard`|`industry`), `enrollment_agreement_id fk` → existing e-sign packet

> Enrollment cannot be created unless the student has a completed e-sign packet and a payment record or approved non-cash pathway. Enforce in a DB function, not in the app.

### 2.3 Sessions & Attendance — *TWC critical*

**`sessions`** — a scheduled instructional block.
`id`, `cohort_id fk`, `session_date`, `start_time`, `end_time`, `scheduled_clock_hours numeric`, `chapter_ids uuid[]`, `instructor_id fk`, `status` (`scheduled`|`held`|`cancelled`|`makeup`), `session_type` (`lecture`|`lab`|`assessment`|`makeup`)

**`attendance_records`** — append-only.
`id`, `enrollment_id fk`, `session_id fk`, `status` (`present`|`absent`|`tardy`|`excused`|`left_early`), `clock_hours_earned numeric`, `minutes_present int`, `recorded_by fk`, `recorded_at`, `supersedes_id fk nullable`, `correction_reason text nullable`

**`clock_hour_ledger`** — a view, not a table. Sums the *current* (non-superseded) attendance rows per enrollment. This is the number that appears on every official document.

Rules to encode:
- `clock_hours_earned` derives from `minutes_present` by a stated rounding rule. **Decide and document the rule now** (recommend: round down to the nearest quarter hour).
- Tardy and left-early still earn partial hours; `absent` earns zero.
- A makeup session's hours attach to the original missed session for reporting.

### 2.4 Assessments

**`question_bank`**
`id`, `program_id fk`, `chapter_id fk nullable`, `stem text`, `type` (`multiple_choice`|`true_false`|`short_answer`), `options jsonb`, `correct_answer jsonb`, `explanation text`, `difficulty`, `is_active bool`, `created_at`

> `correct_answer` and `explanation` are **never** selected by any client-facing query. Enforce with column-level RLS or a dedicated view `question_bank_public` that omits them.

**`assessments`** — a defined instrument.
`id`, `program_id fk`, `kind` (`chapter_quiz`|`practice`|`final_exam`), `form_code` (`A` for Appendix L, `B` for the secure Form B), `title`, `question_count`, `passing_score numeric`, `time_limit_minutes`, `is_secure bool`, `max_attempts int`, `randomize_order bool`

**`assessment_questions`** — fixed mapping for secure exams; for practice quizzes, questions may be drawn dynamically.
`assessment_id fk`, `question_id fk`, `sequence`

**`assessment_attempts`** — append-only.
`id`, `enrollment_id fk`, `assessment_id fk`, `attempt_number`, `started_at`, `submitted_at`, `score numeric`, `passed bool`, `proctored_by fk nullable`, `responses jsonb`, `void bool default false`, `void_reason`

Rules:
- `score` and `passed` are written **only** by a server-side function `grade_attempt(attempt_id)`. No client writes them.
- Form A and Form B are distinct `assessments` rows. A student sits one form; which form is assigned is recorded on the attempt.
- Secure exams (`is_secure = true`) require an `proctored_by` value to be considered valid.

### 2.5 Practical Skill Evaluation

**`skills`** — the evaluable competencies.
`id`, `program_id fk`, `name` (e.g. "TGI Standard Shuffle Sequence", "Side Pot Construction", "Pot Sizing"), `category`, `sequence`

**`skill_benchmarks`** — the objective criteria per tier. This is where zero-discretion lives.
`id`, `skill_id fk`, `tier` (`bronze`|`silver`|`gold`), `criteria jsonb`, `metric_type` (`time`|`accuracy`|`count`|`checklist`), `threshold numeric`, `description text`

**`skill_evaluations`** — append-only.
`id`, `enrollment_id fk`, `skill_id fk`, `evaluated_at`, `evaluator_id fk`, `raw_metric numeric`, `checklist_results jsonb`, `tier_awarded` (computed, not entered), `session_id fk nullable`, `supersedes_id fk nullable`, `notes text`

> `tier_awarded` is set by a DB function comparing `raw_metric` / `checklist_results` against `skill_benchmarks`. The instructor records *what happened*, not *what grade it deserves*. This is the single most important design decision in the spec.

**`current_skill_tier`** — view returning each enrollment's highest non-superseded tier per skill.

### 2.6 Completion

**`completion_evaluations`** — computed snapshot, generated on demand and stored.
`id`, `enrollment_id fk`, `evaluated_at`, `clock_hours_earned`, `attendance_pct`, `final_exam_score`, `all_skills_gold bool`, `perfect_attendance bool`, `outcome` (`not_eligible`|`completed`|`completed_with_distinction`), `criteria_snapshot jsonb`

**`certificates`**
`id`, `enrollment_id fk`, `completion_evaluation_id fk`, `certificate_number` (sequential, gapless), `issued_at`, `issued_by fk`, `pdf_url`, `revoked_at nullable`, `revocation_reason nullable`

Distinction rule, encoded literally:
```
completed_with_distinction :=
     final_exam_score >= 93
 AND every skill has current tier = 'gold'
 AND perfect_attendance = true      -- zero absences, zero tardies
 AND clock_hours_earned >= program.total_clock_hours
```

`criteria_snapshot` stores the full input set at evaluation time so the outcome is reproducible even if benchmarks later change.

---

## 3. Modules (build order)

Build in this order. Each module should be independently demoable.

**M1 — Curriculum & Content**
Seed the 25 chapters, lessons, and resource links from the existing manual. Admin CRUD. Student read-only view. No assessment logic yet.
*Done when:* a student can open the app and browse the full course outline with linked decks and flash cards.

**M2 — Cohorts, Enrollment & Sessions**
Cohort creation, session calendar generation from a cohort's date range and schedule template, roster management.
*Done when:* an admin can create cohort 2026-A, generate its session calendar, and enroll students from existing intake records.

**M3 — Attendance & Clock Hours** *(highest regulatory value — do not defer)*
Instructor take-attendance screen, correction workflow, clock-hour ledger view, printable attendance register.
*Done when:* an instructor can take attendance on a phone in under 60 seconds for a full class, and an admin can export a TWC-format attendance register.

**M4 — Quizzes & Flash Cards**
Non-secure practice assessments and flash card drilling. Server-side grading. Immediate feedback with explanations.
*Done when:* a student can drill chapter 12 flash cards and take the chapter 12 quiz, and results appear on their progress screen.

**M5 — Secure Exams**
Form A / Form B delivery, proctor sign-off, time limits, attempt limits, no answer-key exposure, void workflow.
*Done when:* a proctored 100-question exam can be delivered and graded with no correct answers present in any client payload.

**M6 — Skill Evaluation**
Instructor rubric capture screen, automatic tier computation, per-student skill matrix.
*Done when:* an instructor times a shuffle sequence, records the metric, and the tier is assigned by the system without anyone choosing it.

**M7 — Progress & Dealer Passport**
Student-facing dashboard: clock hours to date, chapters complete, quiz history, skill tiers, distance to Distinction. Wire to the existing Passport artifacts.
*Done when:* a student sees exactly what they still need to finish, with no ambiguity.

**M8 — Completion & Certificates**
Eligibility evaluation, certificate generation, gapless numbering, revocation.
*Done when:* pressing one button on an eligible student produces a numbered certificate PDF and an immutable completion record.

**M9 — Admin Reporting**
Attendance registers, grade rosters, cohort summaries, per-student full file export. Every report needed for an inspection, generated from the ledger — never hand-assembled.

---

## 4. Access Control (Supabase RLS)

Roles: `student`, `instructor`, `admin`.

| Table | student | instructor | admin |
|---|---|---|---|
| curriculum tables | read (visibility=student) | read all | full |
| cohorts, sessions | read own cohort | read/write own cohorts | full |
| attendance_records | read own | insert own sessions | insert, supersede |
| question_bank | **no access** | read via public view | full |
| assessment_attempts | read own, insert own | read own cohort | full |
| skill_evaluations | read own | insert own cohort | insert, supersede |
| completion, certificates | read own | read own cohort | full |

Hard rules:
- No role can `UPDATE` or `DELETE` on `attendance_records`, `assessment_attempts`, `skill_evaluations`, or `completion_evaluations`. Revoke the grants entirely; supersession is an `INSERT`.
- `question_bank.correct_answer` is unreachable from any anon or authenticated client role.
- All grading and tier computation runs in `SECURITY DEFINER` functions.

---

## 5. Server-Side Functions

| function | purpose |
|---|---|
| `grade_attempt(attempt_id)` | Scores responses, writes `score` / `passed`. Sole writer of those columns. |
| `compute_skill_tier(evaluation_id)` | Compares metric to benchmarks, writes `tier_awarded`. Trigger on insert. |
| `evaluate_completion(enrollment_id)` | Produces a `completion_evaluations` row with full snapshot. |
| `issue_certificate(completion_evaluation_id)` | Allocates the next certificate number atomically, generates PDF, writes record. Rejects non-eligible outcomes. |
| `record_attendance_correction(...)` | Inserts a superseding row with reason and actor. |
| `clock_hours_for(enrollment_id)` | Canonical hour total. Every report calls this — nothing recomputes it locally. |

---

## 6. Open Decisions (resolve before M3)

Per the zero-discretion principle, these need answers, not defaults:

1. **Rounding rule** for converting minutes present to clock hours.
2. **Tardy threshold** — at what point does late arrival become absent?
3. **Maximum absences** permitted before termination, and whether makeup hours reset the count.
4. **Perfect attendance definition** — does an excused absence with completed makeup preserve it? (Recommend: no. Distinction should be hard.)
5. **Exam retake policy** — attempts allowed, waiting period, whether a retake caps at the passing score or records the true score.
6. **Form A vs Form B assignment rule** — is Form B reserved for retakes, or randomized per sitting?
7. **Skill re-evaluation** — can a student re-test to raise a tier, and is there a limit?
8. **Certificate numbering format** and starting number.

---

## 7. Notes for Implementation

- Pin the cohort to a `program_id` at creation; never let curriculum edits retroactively alter a past cohort's record.
- Build M3 attendance with offline tolerance. The instructor is on a floor with a phone; assume the network drops. Queue locally, sync on reconnect, and make the sync state visible.
- Every printable report is generated from the ledger functions. If a report can be produced by hand, it will eventually disagree with the database.
- Store `criteria_snapshot` as literal values, not references. References change; snapshots are evidence.
