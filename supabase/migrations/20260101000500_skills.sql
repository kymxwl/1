-- =============================================================================
-- 20260101000500_skills.sql
-- Section 2.5 Practical Skill Evaluation.
--
-- "The instructor records WHAT HAPPENED, not WHAT GRADE it deserves."
-- tier_awarded is computed by compute_skill_tier() (a trigger), comparing the
-- recorded raw_metric / checklist_results against skill_benchmarks. This is
-- the single most important zero-discretion surface in the spec (§2.5).
--
-- skill_evaluations is APPEND-ONLY; re-tests are new rows; highest current
-- (non-superseded) tier wins via the current_skill_tier view.
-- =============================================================================

create table if not exists skills (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references programs(id),
  name        text not null,      -- e.g. "TGI Standard Shuffle Sequence"
  category    text,
  sequence    int not null default 0,
  unique (program_id, name)
);

-- Objective criteria per tier. Where zero-discretion lives.
create table if not exists skill_benchmarks (
  id           uuid primary key default gen_random_uuid(),
  skill_id     uuid not null references skills(id),
  tier         text not null check (tier in ('bronze','silver','gold')),
  criteria     jsonb not null default '{}'::jsonb,
  metric_type  text not null check (metric_type in ('time','accuracy','count','checklist')),
  -- For metric_type='time': threshold is the MAXIMUM seconds (<= passes).
  -- For 'accuracy'/'count': threshold is the MINIMUM (>= passes).
  -- For 'checklist': threshold is the MINIMUM number of required items passed.
  threshold    numeric(10,3) not null,
  description  text,
  unique (skill_id, tier)
);

create table if not exists skill_evaluations (
  id                uuid primary key default gen_random_uuid(),
  enrollment_id     uuid not null references enrollments(id),
  skill_id          uuid not null references skills(id),
  evaluated_at      timestamptz not null default now(),
  evaluator_id      uuid references profiles(id),
  raw_metric        numeric(10,3),                    -- time/accuracy/count value
  checklist_results jsonb not null default '{}'::jsonb, -- {item_key: bool}
  tier_awarded      text check (tier_awarded in ('bronze','silver','gold')), -- computed
  session_id        uuid references sessions(id),
  supersedes_id     uuid references skill_evaluations(id),
  notes             text,
  check (supersedes_id is null or notes is not null)
);

create index if not exists idx_skilleval_enrollment on skill_evaluations(enrollment_id);
create index if not exists idx_skilleval_skill on skill_evaluations(skill_id);

-- -----------------------------------------------------------------------------
-- compute_skill_tier: sets tier_awarded from benchmarks. Trigger on insert.
-- Awards the HIGHEST tier whose benchmark is satisfied by the recorded metric.
-- -----------------------------------------------------------------------------
create or replace function compute_skill_tier()
returns trigger
language plpgsql
as $$
declare
  b            skill_benchmarks%rowtype;
  awarded      text := null;
  passed_items int;
  req_items    int;
begin
  -- Evaluate gold -> silver -> bronze; first satisfied (highest) wins.
  for b in
    select * from skill_benchmarks
    where skill_id = new.skill_id
    order by case tier when 'gold' then 3 when 'silver' then 2 else 1 end desc
  loop
    if b.metric_type = 'time' then
      -- lower is better: pass when raw_metric <= threshold
      if new.raw_metric is not null and new.raw_metric <= b.threshold then
        awarded := b.tier; exit;
      end if;

    elsif b.metric_type in ('accuracy','count') then
      -- higher is better: pass when raw_metric >= threshold
      if new.raw_metric is not null and new.raw_metric >= b.threshold then
        awarded := b.tier; exit;
      end if;

    elsif b.metric_type = 'checklist' then
      -- criteria.required = [item_key,...]; count how many are true.
      select count(*) into req_items
      from jsonb_array_elements_text(coalesce(b.criteria->'required','[]'::jsonb));

      select count(*) into passed_items
      from jsonb_array_elements_text(coalesce(b.criteria->'required','[]'::jsonb)) k
      where coalesce((new.checklist_results ->> k.value)::boolean, false);

      if passed_items >= b.threshold then
        awarded := b.tier; exit;
      end if;
    end if;
  end loop;

  new.tier_awarded := awarded;  -- may be null: recorded but no tier reached
  return new;
end;
$$;

drop trigger if exists trg_compute_skill_tier on skill_evaluations;
create trigger trg_compute_skill_tier
  before insert on skill_evaluations
  for each row execute function compute_skill_tier();
