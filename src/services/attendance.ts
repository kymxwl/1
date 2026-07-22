import { supabase } from '@/lib/supabase';
import type {
  AttendanceRecord, AttendanceStatus, ClockHourLedgerRow, Session,
} from '@/types/database';

/**
 * M3 — Attendance & Clock Hours (highest regulatory value).
 *
 * Records are APPEND-ONLY. This module never updates or deletes: a correction
 * is a new superseding row written by the record_attendance_correction() RPC.
 * clock_hours_earned is computed server-side from minutes_present; the client
 * never sets it.
 */

export interface RosterEntry {
  enrollment_id: string;
  student_name: string;
  current?: AttendanceRecord; // latest non-superseded row for this session, if any
}

/** Canonical clock-hour total for an enrollment (calls the RPC — never local). */
export async function clockHoursFor(enrollmentId: string): Promise<number> {
  const { data, error } = await supabase.rpc('clock_hours_for', {
    p_enrollment_id: enrollmentId,
  });
  if (error) throw error;
  return data ?? 0;
}

export async function getLedger(enrollmentId: string): Promise<ClockHourLedgerRow | null> {
  const { data, error } = await supabase
    .from('clock_hour_ledger')
    .select('*')
    .eq('enrollment_id', enrollmentId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/** Sessions for a cohort (calendar / take-attendance list). */
export async function getCohortSessions(cohortId: string): Promise<Session[]> {
  const { data, error } = await supabase
    .from('sessions')
    .select('*')
    .eq('cohort_id', cohortId)
    .order('session_date', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/** One attendance-mark input for a take-attendance batch. */
export interface AttendanceMark {
  enrollmentId: string;
  status: AttendanceStatus;
  minutesPresent: number;
}

/**
 * Take attendance for a whole session in one batch insert (append-only).
 * Returns the inserted rows (with server-computed clock_hours_earned).
 * Designed for the offline queue: the same payload can be replayed on reconnect.
 */
export async function submitAttendance(
  sessionId: string,
  recordedBy: string,
  marks: AttendanceMark[],
): Promise<AttendanceRecord[]> {
  const rows = marks.map((m) => ({
    enrollment_id: m.enrollmentId,
    session_id: sessionId,
    status: m.status,
    minutes_present: m.status === 'absent' || m.status === 'excused' ? 0 : m.minutesPresent,
    recorded_by: recordedBy,
  }));
  const { data, error } = await supabase
    .from('attendance_records')
    .insert(rows)
    .select('*');
  if (error) throw error;
  return data ?? [];
}

/**
 * Correct a prior attendance record. This does NOT update the old row — the RPC
 * inserts a superseding row carrying the reason and the actor. Returns the new
 * row id.
 */
export async function correctAttendance(params: {
  originalId: string;
  status: AttendanceStatus;
  minutesPresent: number;
  recordedBy: string;
  reason: string;
}): Promise<string> {
  const { data, error } = await supabase.rpc('record_attendance_correction', {
    p_original_id: params.originalId,
    p_status: params.status,
    p_minutes_present: params.minutesPresent,
    p_recorded_by: params.recordedBy,
    p_reason: params.reason,
  });
  if (error) throw error;
  return data as string;
}
