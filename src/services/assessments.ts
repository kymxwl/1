import { supabase } from '@/lib/supabase';
import type {
  Assessment, AssessmentAttempt, QuestionPublic,
} from '@/types/database';

/**
 * M4 (quizzes) + M5 (secure exams).
 *
 * Governing Principle #4: the client fetches questions from question_bank_public
 * — which structurally omits correct_answer and explanation. Grading is done by
 * the grade_attempt() RPC; the client never sees or computes a score.
 *
 * Append-only (Principle #2): an attempt row is WRITE-ONCE. It is inserted at
 * SUBMISSION with the full responses, started_at (captured when the student
 * began), and proctor. The DB guard then forbids any change to identity or
 * responses; grade_attempt() only writes score/passed/submitted_at.
 */

export async function getAssessment(assessmentId: string): Promise<Assessment | null> {
  const { data, error } = await supabase
    .from('assessments').select('*').eq('id', assessmentId).maybeSingle();
  if (error) throw error;
  return data;
}

/** Questions for an assessment, answer-key-free. Order can be randomised UI-side. */
export async function getAssessmentQuestions(assessmentId: string): Promise<QuestionPublic[]> {
  const { data: map, error: mErr } = await supabase
    .from('assessment_questions' as never)
    .select('question_id, sequence')
    .eq('assessment_id', assessmentId)
    .order('sequence');
  if (mErr) throw mErr;
  const ids = ((map ?? []) as { question_id: string }[]).map((m) => m.question_id);
  if (ids.length === 0) return [];

  const { data, error } = await supabase
    .from('question_bank_public').select('*').in('id', ids);
  if (error) throw error;
  return data ?? [];
}

/**
 * Compute the next attempt number and enforce the attempt limit client-side
 * (the DB unique(enrollment, assessment, attempt_number) is the hard backstop).
 * Returns a session token the UI holds while the student works; nothing is
 * persisted until submit.
 */
export interface AttemptSession {
  enrollmentId: string;
  assessmentId: string;
  attemptNumber: number;
  startedAt: string;
  proctoredBy?: string;
}

export async function beginAttempt(params: {
  enrollmentId: string;
  assessment: Assessment;
  proctoredBy?: string;
}): Promise<AttemptSession> {
  const { enrollmentId, assessment, proctoredBy } = params;

  const { data: prior, error } = await supabase
    .from('assessment_attempts')
    .select('attempt_number, void')
    .eq('enrollment_id', enrollmentId)
    .eq('assessment_id', assessment.id);
  if (error) throw error;

  const used = (prior ?? []).filter((a) => !a.void).length;
  if (used >= assessment.max_attempts) {
    throw new Error(
      `Attempt limit reached (${assessment.max_attempts}) for "${assessment.title}".`,
    );
  }
  if (assessment.is_secure && !proctoredBy) {
    throw new Error('This is a secure exam and requires a proctor to begin.');
  }

  const maxNum = (prior ?? []).reduce((m, a) => Math.max(m, a.attempt_number), 0);
  return {
    enrollmentId,
    assessmentId: assessment.id,
    attemptNumber: maxNum + 1,
    startedAt: new Date().toISOString(),
    proctoredBy,
  };
}

/**
 * Write the attempt once (with responses) and grade it. Returns the graded row.
 */
export async function submitAndGrade(
  session: AttemptSession,
  responses: Record<string, unknown>,
): Promise<AssessmentAttempt> {
  const { data: inserted, error: insErr } = await supabase
    .from('assessment_attempts')
    .insert({
      enrollment_id: session.enrollmentId,
      assessment_id: session.assessmentId,
      attempt_number: session.attemptNumber,
      started_at: session.startedAt,
      responses: responses as never,
      proctored_by: session.proctoredBy,
    })
    .select('id')
    .single();
  if (insErr) throw insErr;

  const { error: gErr } = await supabase.rpc('grade_attempt', {
    p_attempt_id: inserted.id,
  });
  if (gErr) throw gErr;

  const { data, error } = await supabase
    .from('assessment_attempts').select('*').eq('id', inserted.id).single();
  if (error) throw error;
  return data;
}

/**
 * Grade an instructor-scored written exam (e.g. Appendix L). `marks` maps each
 * question id to a 0..1 point; the server computes the score. The auto-grader
 * (submitAndGrade) refuses these exams, so this is the grading path for them.
 * Callable by the proctor, the cohort instructor, or an admin.
 */
export async function gradeWrittenAttempt(
  attemptId: string,
  marks: Record<string, number>,
): Promise<number> {
  const { data, error } = await supabase.rpc('grade_written_attempt', {
    p_attempt_id: attemptId,
    p_marks: marks as never,
  });
  if (error) throw error;
  return (data as number) ?? 0;
}

/** Attempt history for a student's progress screen. */
export async function getAttemptHistory(enrollmentId: string): Promise<AssessmentAttempt[]> {
  const { data, error } = await supabase
    .from('assessment_attempts')
    .select('*')
    .eq('enrollment_id', enrollmentId)
    .order('started_at', { ascending: false });
  if (error) throw error;
  return data ?? [];
}
