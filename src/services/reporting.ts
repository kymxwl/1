import { supabase } from '@/lib/supabase';
import type { AttendanceStatus, SkillTier } from '@/types/database';

/**
 * M9 — Admin Reporting. Every figure is read from the ledger / views — nothing
 * is hand-assembled (spec §7: a report that can be produced by hand will
 * eventually disagree with the database).
 */

export interface AttendanceRegisterRow {
  enrollmentId: string;
  studentName: string;
  clockHours: number;
  absences: number;
  tardies: number;
  excused: number;
}

/** TWC-style attendance register for a cohort, straight off the ledger view. */
export async function attendanceRegister(cohortId: string): Promise<AttendanceRegisterRow[]> {
  const { data: enr, error } = await supabase
    .from('enrollments')
    .select('id, students(first_name, last_name)')
    .eq('cohort_id', cohortId);
  if (error) throw error;

  const rows = (enr ?? []) as unknown as {
    id: string; students?: { first_name?: string; last_name?: string } | null;
  }[];
  const ids = rows.map((r) => r.id);
  if (ids.length === 0) return [];

  const { data: ledger, error: lErr } = await supabase
    .from('clock_hour_ledger').select('*').in('enrollment_id', ids);
  if (lErr) throw lErr;
  const byId = new Map((ledger ?? []).map((l) => [l.enrollment_id, l]));

  return rows
    .map((r) => {
      const l = byId.get(r.id);
      return {
        enrollmentId: r.id,
        studentName: `${r.students?.first_name ?? ''} ${r.students?.last_name ?? ''}`.trim() || 'Student',
        clockHours: l?.clock_hours_earned ?? 0,
        absences: l?.absences ?? 0,
        tardies: l?.tardies ?? 0,
        excused: l?.excused_absences ?? 0,
      };
    })
    .sort((a, b) => a.studentName.localeCompare(b.studentName));
}

export interface GradeRosterRow {
  enrollmentId: string;
  studentName: string;
  bestFinalScore: number | null;
  finalPassed: boolean;
  goldSkills: number;
  totalSkills: number;
}

/** Grade roster: best passing final score + skill-tier progress per student. */
export async function gradeRoster(cohortId: string): Promise<GradeRosterRow[]> {
  const { data: enr, error } = await supabase
    .from('enrollments')
    .select('id, students(first_name, last_name)')
    .eq('cohort_id', cohortId);
  if (error) throw error;
  const rows = (enr ?? []) as unknown as {
    id: string; students?: { first_name?: string; last_name?: string } | null;
  }[];
  const ids = rows.map((r) => r.id);
  if (ids.length === 0) return [];

  const [{ data: attempts }, { data: tiers }, { data: skills }] = await Promise.all([
    supabase.from('assessment_attempts')
      .select('enrollment_id, score, passed, assessment_id, void'),
    supabase.from('current_skill_tier').select('*').in('enrollment_id', ids),
    supabase.from('skills').select('id'),
  ]);

  const totalSkills = (skills ?? []).length;

  return rows.map((r) => {
    const mine = (attempts ?? []).filter(
      (a) => a.enrollment_id === r.id && a.passed && !a.void,
    );
    const bestFinal = mine.reduce<number | null>(
      (m, a) => (a.score != null ? Math.max(m ?? 0, a.score) : m), null,
    );
    const gold = (tiers ?? []).filter(
      (t) => t.enrollment_id === r.id && (t.tier as SkillTier) === 'gold',
    ).length;
    return {
      enrollmentId: r.id,
      studentName: `${r.students?.first_name ?? ''} ${r.students?.last_name ?? ''}`.trim() || 'Student',
      bestFinalScore: bestFinal,
      finalPassed: bestFinal != null,
      goldSkills: gold,
      totalSkills,
    };
  });
}

export interface CohortSummary {
  enrolled: number;
  totalClockHours: number;
  avgClockHours: number;
  perfectAttendance: number;
}

/** One-line cohort health summary for the reporting dashboard. */
export async function cohortSummary(cohortId: string): Promise<CohortSummary> {
  const reg = await attendanceRegister(cohortId);
  const enrolled = reg.length;
  const totalClockHours = reg.reduce((s, r) => s + r.clockHours, 0);
  const perfect = reg.filter((r) => r.absences === 0 && r.tardies === 0 && r.excused === 0).length;
  return {
    enrolled,
    totalClockHours,
    avgClockHours: enrolled ? Math.round((totalClockHours / enrolled) * 100) / 100 : 0,
    perfectAttendance: perfect,
  };
}

export const statusLabel: Record<AttendanceStatus, string> = {
  present: 'Present', absent: 'Absent', tardy: 'Tardy',
  excused: 'Excused', left_early: 'Left early',
};
