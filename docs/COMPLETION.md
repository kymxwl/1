# Path to Full Completion

Where the project stands and what remains to take it from **spec-complete code
(CI-green, validated against Postgres)** to **a real institute keeping
TWC-defensible records on students' phones**.

Legend: **[code]** something an engineer/Claude can build · **[you]** ops /
accounts / credentials · **[institute]** curriculum & policy owners ·
**[TWC]** regulatory sign-off.

## Done
- [x] Full data model: 16 migrations — tables, views, server-side functions, RLS, append-only guards.
- [x] Zero-discretion engine: clock hours, skill tiers, pass/fail, completion outcome, gapless certificate numbers — all computed, never entered.
- [x] Answer-key isolation; server-side grading; proctor enforcement.
- [x] All nine modules (M1–M9) with a working UI/console.
- [x] CI: typecheck + migrations/seed/smoke (6 invariant assertions) on every PR.
- [x] **Auth integration (Phase 2):** signup auto-provisions a profile; `set_user_role()` is admin-gated. (this branch)
- [x] Deploy runbook (`DEPLOY.md`).

## Phase 1 — Real backend
- [ ] **[you]** Create Supabase project(s) (staging + prod); hold the refs/keys.
- [ ] **[you]** Run `DEPLOY.md` steps 1–4.
- [ ] **[code+you]** Verify the `issue-certificate` edge function renders + uploads on the real runtime (never executed in CI — no Deno there).

## Phase 2 — Auth & identity — **mostly done**
- [x] **[code]** `handle_new_user` signup trigger + `set_user_role()`.
- [ ] **[you]** Bootstrap the first admin (DEPLOY.md §4).
- [ ] **[decision]** Replace the stand-in `students / enrollment_agreements / payment_records` tables with the real intake / e-sign / payment systems, or build a minimal intake flow. (Spec assumed these already exist in `tgi-app`.)
- [ ] **[code]** Optional integrity FK `profiles.id → auth.users(id)` once off the demo seed (DEPLOY.md hardening).

## Phase 3 — Real content + ratified policy
- [x] **[code]** Curriculum content module (`supabase/content/curriculum_2026_1.sql`) — built from **TGI Manual v1**: the real 25 chapters (four sections, clock hours = 100), lessons whose objectives are the manual's own subsections, and the **Performance Benchmarks** table as skills (Full Shuffle 24/22/20 s, 9-Handed Deal 22/20/18 s, Hand Reading 85/90/95 %, Side Pots & Showdowns pass). Idempotent, institute-editable, freeze-protected once a cohort pins it.
- [x] **[code]** Written exam content module (`supabase/content/exam_appendix_l_2026_1.sql`) — **Appendix L's 100 questions verbatim**, mapped to chapters by category, as the secure Form A written final (pass 70%). They are short-answer/essay with no answer key, so grading uses the new `grade_written_attempt()` (per-question marks → computed score) and `grade_attempt()` refuses them.
- [ ] **[code]** Instructor manual-grading UI for the written exam (backend + service done; screen pending).
- [ ] **[institute]** Add lecture-deck URLs and flash-card decks; expand per-chapter lessons if desired. (Hand-reading workbook, Appendix C, and Form B question set can load as further content modules.)
- [ ] **[decision — flagged]** **Reconcile completion/distinction rules with the manual.** The manual's *Program Completion Requirements* (pass written; **practical ≥ 80% composite**; **Silver+** in all timed/accuracy skills; competency in each game variant; attendance **≥ 90%**) and *Distinction* (**93%+ on BOTH written AND practical**, Gold in all skills, **no game-protection failures**, perfect attendance) are **stricter/broader than the implemented rule** (which follows the original spec: written ≥ 93, all-gold, perfect attendance, full hours). Aligning to the manual needs a modeled **practical-exam score** and a **game-protection-failure** signal, plus an edit to `evaluate_completion()`. Do NOT change silently — ratify with the institute/TWC first.
- [ ] **[institute]** Full question banks: Appendix L **Form A** and secure **Form B** (~100 each), with explanations.
- [ ] **[institute]** Skill benchmarks (Bronze/Silver/Gold thresholds) per competency.
- [ ] **[TWC + institute]** Ratify the 8 Open Decisions in `docs/DECISIONS.md` (stored as data — confirm or edit values, no code change).
- [ ] **[code]** Bulk-import tooling (CSV) + admin content-CRUD screens so non-engineers maintain all of the above.

## Phase 4 — Testing & hardening
- [ ] **[code]** Per-role RLS test matrix (prove no cross-student reads, no answer-key access).
- [ ] **[code]** Service-layer unit tests; offline-queue network-drop test.
- [ ] **[you]** Security review + accessibility pass before real PII.

## Phase 5 — Ship to devices
- [ ] **[you]** Apple Developer + Google Play (or MDM/internal) + EAS accounts.
- [ ] **[code]** EAS build config, icons/splash, env handling, build-and-distribute guide.

## Phase 6 — Compliance & operations
- [ ] **[TWC + institute]** Confirm the M9 attendance register / grade roster columns match the exact TWC inspection forms.
- [ ] **[you]** Data retention, backups, PII handling policy.
- [ ] **[code]** Audit logging on sensitive tables; automated backups; error monitoring (e.g. Sentry).

## Phase 7 — Remaining UX polish
- [ ] **[code]** Date-pickers in the cohort form; cohort/session edit flows.
- [ ] **[code]** Certificate-revocation UI; makeup-session workflow.
- [ ] **[code]** Empty/error/loading states; roster pagination for large cohorts.

---

### Critical-path summary
**Auth (done) → real backend + first admin (Phase 1–2) → real content + TWC
ratification (Phase 3) → testing/compliance (4 & 6) → device shipping (5).**
Phases 3, 5, and 6 have hard dependencies on the institute, you, and TWC that
code cannot substitute for.
