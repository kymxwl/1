/**
 * Typed schema for supabase-js. In a real workflow this file is generated:
 *   npm run db:types   (supabase gen types typescript --local)
 * It is hand-authored here so the app is self-describing without a running
 * Supabase project. Keep it in sync with supabase/migrations when the schema
 * changes, or regenerate.
 */

export type AppRole = 'student' | 'instructor' | 'admin';
export type SkillTier = 'bronze' | 'silver' | 'gold';
export type AttendanceStatus =
  | 'present' | 'absent' | 'tardy' | 'excused' | 'left_early';
export type CompletionOutcome =
  | 'not_eligible' | 'completed' | 'completed_with_distinction';
export type AssessmentKind = 'chapter_quiz' | 'practice' | 'final_exam';
export type QuestionType = 'multiple_choice' | 'true_false' | 'short_answer';

type Json = string | number | boolean | null | { [k: string]: Json } | Json[];

/** Convenience row types used across services and screens. */
export interface Program {
  id: string; name: string; version: string;
  total_clock_hours: number; is_active: boolean; effective_date: string;
}
export interface Course {
  id: string; program_id: string; name: string; sequence: number; clock_hours: number;
}
export interface Chapter {
  id: string; course_id: string; number: number; title: string;
  sequence: number; clock_hours: number; manual_page_ref: string | null;
}
export interface Lesson {
  id: string; chapter_id: string; title: string; sequence: number;
  objectives: Json; lecture_deck_url: string | null;
  instructor_notes_url: string | null; estimated_minutes: number;
}
export interface Resource {
  id: string; owner_type: 'program' | 'course' | 'chapter' | 'lesson';
  owner_id: string; kind: 'deck' | 'flashcards' | 'video' | 'handout' | 'manual';
  title: string; url: string; visibility: 'student' | 'instructor' | 'admin';
}
export interface Session {
  id: string; cohort_id: string; session_date: string;
  start_time: string; end_time: string; scheduled_clock_hours: number;
  chapter_ids: string[]; instructor_id: string | null;
  status: 'scheduled' | 'held' | 'cancelled' | 'makeup';
  session_type: 'lecture' | 'lab' | 'assessment' | 'makeup';
}
export interface Enrollment {
  id: string; student_id: string; cohort_id: string; enrolled_at: string;
  status: 'enrolled' | 'active' | 'withdrawn' | 'completed' | 'terminated';
  status_reason: string | null; tuition_rate: 'standard' | 'industry';
  enrollment_agreement_id: string | null;
}
export interface AttendanceRecord {
  id: string; enrollment_id: string; session_id: string;
  status: AttendanceStatus; clock_hours_earned: number; minutes_present: number;
  recorded_by: string | null; recorded_at: string;
  supersedes_id: string | null; correction_reason: string | null;
}
export interface ClockHourLedgerRow {
  enrollment_id: string; cohort_id: string; clock_hours_earned: number;
  absences: number; tardies: number; excused_absences: number;
  left_early_count: number;
}
export interface QuestionPublic {
  id: string; program_id: string; chapter_id: string | null; stem: string;
  type: QuestionType; options: Json; difficulty: string | null; is_active: boolean;
}
export interface Assessment {
  id: string; program_id: string; kind: AssessmentKind;
  form_code: 'A' | 'B' | null; title: string; question_count: number;
  passing_score: number; time_limit_minutes: number | null;
  is_secure: boolean; max_attempts: number; randomize_order: boolean;
}
export interface AssessmentAttempt {
  id: string; enrollment_id: string; assessment_id: string;
  attempt_number: number; started_at: string; submitted_at: string | null;
  score: number | null; passed: boolean | null; proctored_by: string | null;
  responses: Json; void: boolean; void_reason: string | null;
}
export interface Flashcard {
  id: string; chapter_id: string; front: string; back: string;
  sequence: number; is_active: boolean;
}
export interface Skill {
  id: string; program_id: string; name: string;
  category: string | null; sequence: number;
}
export interface SkillBenchmark {
  id: string; skill_id: string; tier: SkillTier; criteria: Json;
  metric_type: 'time' | 'accuracy' | 'count' | 'checklist';
  threshold: number; description: string | null;
}
export interface SkillEvaluation {
  id: string; enrollment_id: string; skill_id: string; evaluated_at: string;
  evaluator_id: string | null; raw_metric: number | null;
  checklist_results: Json; tier_awarded: SkillTier | null;
  session_id: string | null; supersedes_id: string | null; notes: string | null;
}
export interface CurrentSkillTierRow {
  enrollment_id: string; skill_id: string; tier: SkillTier;
}
export interface CompletionEvaluation {
  id: string; enrollment_id: string; evaluated_at: string;
  clock_hours_earned: number; attendance_pct: number;
  final_exam_score: number | null; all_skills_gold: boolean;
  perfect_attendance: boolean; outcome: CompletionOutcome; criteria_snapshot: Json;
}
export interface Certificate {
  id: string; enrollment_id: string; completion_evaluation_id: string;
  certificate_number: string; issued_at: string; issued_by: string | null;
  pdf_url: string | null; revoked_at: string | null;
  revocation_reason: string | null;
}

/**
 * `Loosen<T>` maps an interface into an anonymous object type so it satisfies
 * supabase-js's `Record<string, unknown>` constraints. (Interfaces lack an
 * implicit index signature and are otherwise rejected by GenericSchema.)
 */
type Loosen<T> = { [K in keyof T]: T[K] };

/** Minimal generic helper so `.from(table)` is typed for common tables. */
type TableDef<R, I = Partial<R>, U = Partial<R>> = {
  Row: Loosen<R>; Insert: Loosen<I>; Update: Loosen<U>; Relationships: [];
};

export interface Database {
  public: {
    Tables: {
      programs: TableDef<Program>;
      courses: TableDef<Course>;
      chapters: TableDef<Chapter>;
      lessons: TableDef<Lesson>;
      resources: TableDef<Resource>;
      sessions: TableDef<Session>;
      enrollments: TableDef<Enrollment>;
      attendance_records: TableDef<
        AttendanceRecord,
        Pick<AttendanceRecord, 'enrollment_id' | 'session_id' | 'status' | 'minutes_present'> &
          Partial<Pick<AttendanceRecord, 'recorded_by' | 'supersedes_id' | 'correction_reason'>>
      >;
      question_bank: TableDef<QuestionPublic>;
      assessments: TableDef<Assessment>;
      assessment_attempts: TableDef<
        AssessmentAttempt,
        Pick<AssessmentAttempt, 'enrollment_id' | 'assessment_id' | 'attempt_number' | 'responses'> &
          Partial<Pick<AssessmentAttempt, 'proctored_by' | 'started_at'>>
      >;
      flashcards: TableDef<Flashcard>;
      skills: TableDef<Skill>;
      skill_benchmarks: TableDef<SkillBenchmark>;
      skill_evaluations: TableDef<
        SkillEvaluation,
        Pick<SkillEvaluation, 'enrollment_id' | 'skill_id'> &
          Partial<Pick<SkillEvaluation, 'evaluator_id' | 'raw_metric' | 'checklist_results' | 'session_id' | 'notes' | 'supersedes_id'>>
      >;
      completion_evaluations: TableDef<CompletionEvaluation>;
      certificates: TableDef<Certificate>;
    };
    Views: {
      clock_hour_ledger: { Row: Loosen<ClockHourLedgerRow>; Relationships: [] };
      current_skill_tier: { Row: Loosen<CurrentSkillTierRow>; Relationships: [] };
      question_bank_public: { Row: Loosen<QuestionPublic>; Relationships: [] };
    };
    Functions: {
      clock_hours_for: { Args: { p_enrollment_id: string }; Returns: number };
      grade_attempt: { Args: { p_attempt_id: string }; Returns: number };
      evaluate_completion: { Args: { p_enrollment_id: string }; Returns: string };
      issue_certificate: {
        Args: { p_completion_evaluation_id: string; p_issued_by?: string };
        Returns: string;
      };
      record_attendance_correction: {
        Args: {
          p_original_id: string; p_status: string; p_minutes_present: number;
          p_recorded_by: string; p_reason: string;
        };
        Returns: string;
      };
      current_app_role: { Args: Record<string, never>; Returns: AppRole };
      set_user_role: { Args: { p_user_id: string; p_role: AppRole }; Returns: undefined };
      attempt_feedback: { Args: { p_attempt_id: string }; Returns: Json };
      generate_cohort_sessions: {
        Args: {
          p_cohort_id: string; p_weekdays: number[]; p_start_time: string;
          p_end_time: string; p_scheduled_clock_hours: number; p_session_type?: string;
        };
        Returns: number;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
