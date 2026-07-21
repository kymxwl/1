import { supabase } from '@/lib/supabase';
import type {
  Skill, SkillBenchmark, SkillEvaluation, SkillTier,
} from '@/types/database';

/**
 * M6 — Skill Evaluation.
 *
 * The instructor records WHAT HAPPENED (raw_metric / checklist_results); the
 * tier is computed by the DB trigger compute_skill_tier(). No client code and
 * no instructor input chooses the tier (Principle #3). Evaluations are
 * append-only; a re-test is a new (optionally superseding) row.
 */

export async function getSkills(programId: string): Promise<Skill[]> {
  const { data, error } = await supabase
    .from('skills').select('*').eq('program_id', programId).order('sequence');
  if (error) throw error;
  return data ?? [];
}

export async function getBenchmarks(skillId: string): Promise<SkillBenchmark[]> {
  const { data, error } = await supabase
    .from('skill_benchmarks').select('*').eq('skill_id', skillId);
  if (error) throw error;
  return data ?? [];
}

/** Current highest tier per skill for one enrollment (from the view). */
export async function getCurrentTiers(
  enrollmentId: string,
): Promise<Record<string, SkillTier>> {
  const { data, error } = await supabase
    .from('current_skill_tier').select('*').eq('enrollment_id', enrollmentId);
  if (error) throw error;
  const out: Record<string, SkillTier> = {};
  for (const row of data ?? []) out[row.skill_id] = row.tier;
  return out;
}

/**
 * Record a skill evaluation. Provide EITHER raw_metric (time/accuracy/count) OR
 * checklist_results — matching the skill's benchmark metric_type. The returned
 * row carries tier_awarded as computed by the trigger.
 */
export async function recordEvaluation(params: {
  enrollmentId: string;
  skillId: string;
  evaluatorId: string;
  rawMetric?: number;
  checklistResults?: Record<string, boolean>;
  sessionId?: string;
  notes?: string;
  supersedesId?: string;
}): Promise<SkillEvaluation> {
  const { data, error } = await supabase
    .from('skill_evaluations')
    .insert({
      enrollment_id: params.enrollmentId,
      skill_id: params.skillId,
      evaluator_id: params.evaluatorId,
      raw_metric: params.rawMetric,
      checklist_results: (params.checklistResults ?? {}) as never,
      session_id: params.sessionId,
      notes: params.notes,
      supersedes_id: params.supersedesId,
    })
    .select('*')
    .single();
  if (error) throw error;
  return data; // tier_awarded computed by DB trigger
}
