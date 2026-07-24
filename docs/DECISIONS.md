# Resolved Open Decisions (Spec §6)

The spec requires these to be answered — not defaulted — before M3. Each is
resolved below and **encoded as stored data or a deterministic rule**, per
Governing Principle #3 (zero discretion). Values marked _proposed_ are the
recommended defaults shipped in `attendance_policies` / the SQL; they are the
institute's to ratify with TWC, and changing them is a data edit, not a code
change.

| # | Decision | Resolution | Where it lives |
|---|----------|-----------|----------------|
| 1 | **Rounding rule** | Round **down to the nearest quarter hour** (15 min). 200 min → 3.25 hr. | `attendance_policies.rounding_minutes = 15`; applied by `compute_attendance_hours()` trigger. |
| 2 | **Tardy threshold** | Arriving **> 10 min** after start is `tardy` (still earns hours for minutes present). Below `absent_floor_minutes` (1) present ⇒ `absent`, 0 hours. | `attendance_policies.tardy_threshold_minutes = 10`, `absent_floor_minutes = 1`. Status is a label the instructor records; hours are computed from `minutes_present` regardless. |
| 3 | **Max absences before termination** | **3** absences triggers a termination review. A completed makeup **restores the clock hours** for the missed session but **does not decrement the absence count** (`makeup_resets_absence = false`). | `attendance_policies.max_absences = 3`, `makeup_resets_absence = false`. The ledger view exposes `absences`; termination itself is an admin action recorded on `enrollments.status`. |
| 4 | **Perfect attendance** | **Zero absences AND zero tardies AND zero excused.** An excused absence with a completed makeup does **not** preserve it — Distinction is deliberately hard. | Computed in `evaluate_completion()`: `perfect = absences=0 AND tardies=0 AND excused=0`. |
| 5 | **Exam retake policy** | Attempts capped by `assessments.max_attempts` (final exam = 1 per form; practice = 5). A retake records the **true score** (append-only evidence), never a capped score. Best **passing** score is used for completion. Waiting period is enforced operationally by the proctor (not a hard DB lock in v1). | `assessments.max_attempts`; `evaluate_completion()` selects `max(score)` among non-void passing final attempts. |
| 6 | **Form A vs Form B** | Form A (Appendix L) is the **standard first sitting**; Form B (secure) is the **retake / alternate** form. Both are distinct `assessments` rows and both are secure + proctored. The form actually sat is recorded by which `assessment_id` the attempt references. | Two `assessments` rows (`form_code` A/B). Assignment is an operational/admin choice at scheduling time. |
| 7 | **Skill re-evaluation** | A student may re-test a skill **any number of times** to raise a tier. Each test is a new `skill_evaluations` row; the **highest current tier wins** via `current_skill_tier`. No cap in v1. | Append-only `skill_evaluations`; `current_skill_tier` view ranks gold > silver > bronze. |
| 8 | **Certificate numbering** | Format `TGI-######` (6-digit, zero-padded), **globally sequential and gapless**, starting at `TGI-000001`. | `certificate_counter` row locked + incremented inside `issue_certificate()`. |

## Clock-hour derivation (the defensible ledger)

```
clock_hours_earned = floor(minutes_present / rounding_minutes) * rounding_minutes / 60
```

- `absent` and `excused` ⇒ `minutes_present = 0` ⇒ 0 hours.
- `tardy` and `left_early` earn partial hours for the minutes actually present.
- A makeup session carries its own earned hours; the original missed session's
  `absent` row earned 0. For reporting, a makeup session references the original
  via `sessions.makeup_for_session_id`.

The number that appears on every official document is `clock_hour_ledger`
(a view over **non-superseded** rows) surfaced by `clock_hours_for()`. No report
recomputes hours locally.

## Regular "completed" vs "not_eligible" (beyond Distinction)

The spec defines Distinction literally but leaves the baseline implicit. Encoded
in `evaluate_completion()`. **As of migration `..._completion_manual.sql` this
follows TGI Manual v1** (Program Completion Requirements + Graduate Distinction),
which supersedes the original spec §2.6 rule:

```
completed :=
      clock_hours_earned >= program.total_clock_hours
  AND a non-void WRITTEN exam attempt passed        (final_exam, pass 70%)
  AND a non-void PRACTICAL exam attempt passed      (final_practical, pass 80%)
  AND every defined skill current tier >= 'silver'
  AND attendance_pct >= 90

completed_with_distinction :=
      written_best  >= 93
  AND practical_best >= 93
  AND every skill current tier = 'gold'
  AND game_protection_failures = 0
  AND perfect_attendance                  -- zero absences, tardies, excused
  AND clock_hours_earned >= program.total_clock_hours

otherwise := not_eligible
```

`criteria_snapshot` stores the literal inputs (including `rule_source =
'TGI Manual v1'`) so the outcome is reproducible years later.

**Attested gates NOT auto-decided.** The manual also requires *professional
conduct*, *instructor completion sign-off*, and *verified competency in each
game variant*. These need human attestation / additional modeling and are
tracked in `docs/COMPLETION.md`; `evaluate_completion()` computes only the
objective gates above. The practical-exam **instrument** (Ch 25 categories &
scoring) and the game-protection-incident UI are likewise pending — the schema
(`final_practical` kind, `game_protection_incidents` table) and the rule are in
place now.
