import { supabase } from '@/lib/supabase';
import type { Certificate, CompletionEvaluation } from '@/types/database';

/**
 * M7/M8 — Completion & Certificates.
 *
 * evaluate_completion() computes an outcome from stored data and writes a
 * snapshot row; no human types the outcome. issue_certificate() allocates the
 * next gapless number and rejects non-eligible outcomes. Both are RPCs.
 */

/** Run (and store) a fresh completion evaluation; returns the snapshot row. */
export async function evaluateCompletion(enrollmentId: string): Promise<CompletionEvaluation> {
  const { data: evalId, error } = await supabase.rpc('evaluate_completion', {
    p_enrollment_id: enrollmentId,
  });
  if (error) throw error;
  const { data, error: rErr } = await supabase
    .from('completion_evaluations').select('*').eq('id', evalId as string).single();
  if (rErr) throw rErr;
  return data;
}

/** Most recent completion evaluation for an enrollment, if any. */
export async function latestEvaluation(
  enrollmentId: string,
): Promise<CompletionEvaluation | null> {
  const { data, error } = await supabase
    .from('completion_evaluations')
    .select('*')
    .eq('enrollment_id', enrollmentId)
    .order('evaluated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/** Issue a certificate for an eligible completion evaluation (admin action). */
export async function issueCertificate(
  completionEvaluationId: string,
  issuedBy: string,
): Promise<Certificate> {
  const { data: certId, error } = await supabase.rpc('issue_certificate', {
    p_completion_evaluation_id: completionEvaluationId,
    p_issued_by: issuedBy,
  });
  if (error) throw error;
  const { data, error: rErr } = await supabase
    .from('certificates').select('*').eq('id', certId as string).single();
  if (rErr) throw rErr;
  return data;
}

/** Human-readable distance-to-Distinction from a completion snapshot. */
export function distanceToDistinction(ev: CompletionEvaluation): string[] {
  if (ev.outcome === 'completed_with_distinction') return [];
  const gaps: string[] = [];
  const s = (ev.criteria_snapshot ?? {}) as Record<string, unknown>;
  const finalScore = (s.best_final_exam_score as number | null) ?? ev.final_exam_score;
  const total = (s.total_clock_hours as number) ?? 100;

  if ((finalScore ?? 0) < 93) gaps.push(`Final exam ≥ 93 (currently ${finalScore ?? '—'})`);
  if (!ev.all_skills_gold) gaps.push('Every skill at Gold tier');
  if (!ev.perfect_attendance) gaps.push('Perfect attendance (zero absences & tardies)');
  if (ev.clock_hours_earned < total) {
    gaps.push(`Clock hours ${ev.clock_hours_earned}/${total}`);
  }
  return gaps;
}
