import { supabase } from '@/lib/supabase';
import type { Flashcard, QuestionType } from '@/types/database';

/**
 * M4 — Quizzes & Flash Cards (client surface).
 *
 * Flash cards are study content (front/back) — separate from question_bank, so
 * nothing here can leak a secure exam's answer key. Quiz feedback is fetched
 * from attempt_feedback(), which only returns the key AFTER submission and only
 * for non-secure practice quizzes.
 */

export async function getFlashcards(chapterId: string): Promise<Flashcard[]> {
  const { data, error } = await supabase
    .from('flashcards')
    .select('*')
    .eq('chapter_id', chapterId)
    .eq('is_active', true)
    .order('sequence');
  if (error) throw error;
  return data ?? [];
}

export interface QuestionFeedback {
  question_id: string;
  stem: string;
  type: QuestionType;
  options: { key: string; text: string }[];
  given: unknown;
  correct_answer: unknown;
  explanation: string | null;
  is_correct: boolean;
}

/** Post-submission feedback for a non-secure practice attempt. */
export async function getAttemptFeedback(attemptId: string): Promise<QuestionFeedback[]> {
  const { data, error } = await supabase.rpc('attempt_feedback', { p_attempt_id: attemptId });
  if (error) throw error;
  return (data ?? []) as unknown as QuestionFeedback[];
}
