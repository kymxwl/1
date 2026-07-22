import { supabase } from '@/lib/supabase';
import type { Session } from '@/types/database';

/**
 * M2 — Cohorts, Enrollment & Sessions.
 *
 * Cohort creation, calendar generation (via the generate_cohort_sessions RPC),
 * and roster management: enrol students who already have a completed e-sign
 * packet + approved payment (the DB trigger enforces this regardless).
 */

export interface CohortRow {
  id: string;
  program_id: string;
  name: string;
  start_date: string;
  end_date: string;
  instructor_id: string | null;
  capacity: number;
  status: 'planned' | 'active' | 'completed' | 'cancelled';
  location: string | null;
}

export async function listCohorts(programId: string): Promise<CohortRow[]> {
  const { data, error } = await supabase
    .from('cohorts' as never)
    .select('*')
    .eq('program_id', programId)
    .order('start_date', { ascending: false });
  if (error) throw error;
  return (data ?? []) as unknown as CohortRow[];
}

export async function createCohort(input: {
  programId: string;
  name: string;
  startDate: string;   // YYYY-MM-DD
  endDate: string;
  instructorId?: string;
  capacity?: number;
  location?: string;
}): Promise<CohortRow> {
  const { data, error } = await supabase
    .from('cohorts' as never)
    .insert({
      program_id: input.programId,
      name: input.name,
      start_date: input.startDate,
      end_date: input.endDate,
      instructor_id: input.instructorId ?? null,
      capacity: input.capacity ?? 24,
      location: input.location ?? null,
      status: 'planned',
    } as never)
    .select('*')
    .single();
  if (error) throw error;
  return data as unknown as CohortRow;
}

export interface ScheduleTemplate {
  weekdays: number[];       // ISO dow: 1=Mon … 7=Sun
  startTime: string;        // "HH:MM"
  endTime: string;
  clockHours: number;
  sessionType?: 'lecture' | 'lab' | 'assessment' | 'makeup';
}

/** Generate the session calendar; returns the number of rows inserted. */
export async function generateSessions(
  cohortId: string,
  t: ScheduleTemplate,
): Promise<number> {
  const { data, error } = await supabase.rpc('generate_cohort_sessions', {
    p_cohort_id: cohortId,
    p_weekdays: t.weekdays,
    p_start_time: t.startTime,
    p_end_time: t.endTime,
    p_scheduled_clock_hours: t.clockHours,
    p_session_type: t.sessionType ?? 'lecture',
  });
  if (error) throw error;
  return (data as number) ?? 0;
}

export async function getCohortSessions(cohortId: string): Promise<Session[]> {
  const { data, error } = await supabase
    .from('sessions')
    .select('*')
    .eq('cohort_id', cohortId)
    .order('session_date', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export interface RosterMember {
  enrollmentId: string;
  studentId: string;
  name: string;
  status: string;
}

export async function getRoster(cohortId: string): Promise<RosterMember[]> {
  const { data, error } = await supabase
    .from('enrollments')
    .select('id, student_id, status, students(first_name, last_name)')
    .eq('cohort_id', cohortId);
  if (error) throw error;
  return ((data ?? []) as unknown as {
    id: string; student_id: string; status: string;
    students?: { first_name?: string; last_name?: string } | null;
  }[]).map((e) => ({
    enrollmentId: e.id,
    studentId: e.student_id,
    name: `${e.students?.first_name ?? ''} ${e.students?.last_name ?? ''}`.trim() || 'Student',
    status: e.status,
  }));
}

export interface EnrollableStudent {
  studentId: string;
  name: string;
  agreementId: string;
}

/**
 * Students eligible to enrol: a completed e-sign packet AND an approved payment
 * pathway, not already enrolled in this cohort. (The DB trigger re-checks the
 * prerequisites on insert, so this is a convenience filter, not the guarantee.)
 */
export async function listEnrollableStudents(cohortId: string): Promise<EnrollableStudent[]> {
  const [{ data: agreements, error: aErr }, { data: payments, error: pErr }, { data: enrolled, error: eErr }] =
    await Promise.all([
      supabase.from('enrollment_agreements' as never).select('id, student_id, is_complete').eq('is_complete', true),
      supabase.from('payment_records' as never).select('student_id, is_approved').eq('is_approved', true),
      supabase.from('enrollments').select('student_id').eq('cohort_id', cohortId),
    ]);
  if (aErr) throw aErr;
  if (pErr) throw pErr;
  if (eErr) throw eErr;

  const paidIds = new Set(((payments ?? []) as { student_id: string }[]).map((p) => p.student_id));
  const enrolledIds = new Set((enrolled ?? []).map((e) => e.student_id));
  const ags = (agreements ?? []) as { id: string; student_id: string }[];

  const seen = new Set<string>();
  const eligibleIds: { studentId: string; agreementId: string }[] = [];
  for (const a of ags) {
    if (paidIds.has(a.student_id) && !enrolledIds.has(a.student_id) && !seen.has(a.student_id)) {
      seen.add(a.student_id);
      eligibleIds.push({ studentId: a.student_id, agreementId: a.id });
    }
  }
  if (eligibleIds.length === 0) return [];

  const { data: students, error: sErr } = await supabase
    .from('students' as never)
    .select('id, first_name, last_name')
    .in('id', eligibleIds.map((e) => e.studentId));
  if (sErr) throw sErr;

  const byId = new Map(((students ?? []) as { id: string; first_name: string; last_name: string }[])
    .map((s) => [s.id, s]));
  return eligibleIds.map((e) => {
    const s = byId.get(e.studentId);
    return {
      studentId: e.studentId,
      agreementId: e.agreementId,
      name: s ? `${s.first_name} ${s.last_name}`.trim() : 'Student',
    };
  });
}

/** Enrol a student. The DB trigger blocks enrolment without packet + payment. */
export async function enrollStudent(input: {
  studentId: string;
  cohortId: string;
  agreementId: string;
  tuitionRate?: 'standard' | 'industry';
}): Promise<void> {
  const { error } = await supabase.from('enrollments').insert({
    student_id: input.studentId,
    cohort_id: input.cohortId,
    enrollment_agreement_id: input.agreementId,
    tuition_rate: input.tuitionRate ?? 'standard',
    status: 'enrolled',
  } as never);
  if (error) throw error;
}
