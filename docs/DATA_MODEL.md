# Data Model & Design Notes

Implements Spec §2. Every governing principle maps to a concrete mechanism.

## Governing principles → mechanisms

| Principle | Mechanism |
|-----------|-----------|
| #1 One student identity | LMS FKs point at the existing `students`/`profiles` rows. No second student table. Enrollment reuses the e-sign packet + payment record. |
| #2 Records TWC may inspect are append-only | `attendance_records`, `assessment_attempts`, `skill_evaluations`, `completion_evaluations`: no UPDATE/DELETE policy, grants revoked, and `block_mutation()` / `guard_attempt_mutation()` triggers reject mutation at the table level. Corrections/re-tests are new rows with `supersedes_id` + reason. |
| #3 Zero discretion at decision points | `clock_hours_earned`, `tier_awarded`, `passed`, and `outcome` are all **computed** by triggers/functions from stored data. No column accepts a hand-typed outcome. |
| #4 Answer keys never reach the client | `question_bank.correct_answer`/`explanation` have **no** student/instructor SELECT policy; clients read `question_bank_public`. Grading runs in `grade_attempt()` (SECURITY DEFINER). |
| #5 Clock hours are the regulatory unit | `clock_hour_ledger` view + `clock_hours_for()` are the single source of the hour total on every document. |

## Tables (24) — by module

- **Identity (reused):** `profiles`, `students`, `enrollment_agreements`, `payment_records`
- **Curriculum (§2.1):** `programs`, `courses`, `chapters`, `lessons`, `resources`
- **Cohorts (§2.2):** `cohorts`, `enrollments`
- **Attendance (§2.3):** `attendance_policies`, `sessions`, `attendance_records`
- **Assessments (§2.4):** `question_bank`, `assessments`, `assessment_questions`, `assessment_attempts`
- **Skills (§2.5):** `skills`, `skill_benchmarks`, `skill_evaluations`
- **Completion (§2.6):** `completion_evaluations`, `certificate_counter`, `certificates`

## Views (4)

| View | Purpose |
|------|---------|
| `attendance_current` | Non-superseded attendance rows (basis of the ledger). |
| `clock_hour_ledger` | Sums current hours per enrollment + absence/tardy counts. |
| `current_skill_tier` | Highest current tier per enrollment/skill. |
| `question_bank_public` | Questions with the answer key omitted. |

## Server-side functions (§5)

| Function | Guarantee |
|----------|-----------|
| `clock_hours_for(enrollment)` | Canonical hour total. |
| `grade_attempt(attempt)` | Sole writer of `score`/`passed`; enforces proctor on secure exams. |
| `compute_skill_tier()` (trigger) | Sole writer of `tier_awarded`. |
| `record_attendance_correction(...)` | Inserts a superseding row with reason + actor. |
| `evaluate_completion(enrollment)` | Writes a snapshot row + deterministic outcome. |
| `issue_certificate(eval)` | Atomic gapless number; rejects non-eligible outcomes. |

## Immutability model

A single write to an attempt happens **once** at submission (responses +
`started_at` + proctor). `grade_attempt()` afterwards may only write
`score`/`passed`/`submitted_at`; the guard trigger rejects any change to
identity or `responses`, and all DELETEs. Attendance and skill evaluations
accept **no** post-insert change at all — supersession is a new INSERT.

## Curriculum versioning

Curriculum is versioned at the `programs` level. Once any cohort references a
program, `assert_program_not_frozen()` blocks structural edits to that program,
its courses, chapters, and lessons — new curriculum must be a new program
version. This is what makes "what exactly was this graduate taught" answerable
years later.
