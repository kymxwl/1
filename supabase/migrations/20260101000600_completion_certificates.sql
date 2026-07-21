-- =============================================================================
-- 20260101000600_completion_certificates.sql
-- Section 2.6 Completion & Certificates.
--
-- completion_evaluations is a COMPUTED snapshot (append-only evidence).
-- criteria_snapshot stores literal input values so the outcome is reproducible
-- even if benchmarks/curriculum later change (spec §2.6, §7).
--
-- certificate_number is sequential + GAPLESS -- allocated atomically by
-- issue_certificate() via a locked counter row (see functions migration).
-- =============================================================================

create table if not exists completion_evaluations (
  id                 uuid primary key default gen_random_uuid(),
  enrollment_id      uuid not null references enrollments(id),
  evaluated_at       timestamptz not null default now(),
  clock_hours_earned numeric(6,2) not null,
  attendance_pct     numeric(5,2) not null,
  final_exam_score   numeric(5,2),
  all_skills_gold    boolean not null,
  perfect_attendance boolean not null,
  outcome            text not null
                       check (outcome in ('not_eligible','completed','completed_with_distinction')),
  criteria_snapshot  jsonb not null
);

create index if not exists idx_completion_enrollment on completion_evaluations(enrollment_id);

-- Gapless counter. One row per series; issue_certificate() locks + increments.
create table if not exists certificate_counter (
  series      text primary key default 'default',
  last_number bigint not null default 0
);
insert into certificate_counter (series, last_number)
  values ('default', 0)
  on conflict (series) do nothing;

create table if not exists certificates (
  id                        uuid primary key default gen_random_uuid(),
  enrollment_id             uuid not null references enrollments(id),
  completion_evaluation_id  uuid not null references completion_evaluations(id),
  certificate_number        text not null unique,     -- e.g. "TGI-000001"
  issued_at                 timestamptz not null default now(),
  issued_by                 uuid references profiles(id),
  pdf_url                   text,
  revoked_at                timestamptz,
  revocation_reason         text,
  -- One live (non-revoked) certificate per enrollment.
  unique (enrollment_id)
);
