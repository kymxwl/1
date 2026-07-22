/**
 * Seed identifiers used to wire the demo/staff console to concrete rows without
 * a full picker UI. In production these are chosen from live cohort/session
 * lists; here they point at the rows created by supabase/seed.sql.
 */
export const DEMO = {
  programId: '00000000-0000-0000-0000-000000000001',
  cohortId: '00000000-0000-0000-0000-000000000401',
  sessionId: '00000000-0000-0000-0000-000000000601',
  enrollmentId: '00000000-0000-0000-0000-000000000501',
  finalFormA: '00000000-0000-0000-0000-000000000202',
  chapterQuiz: '00000000-0000-0000-0000-000000000201',
  flashcardChapterNumber: 12,
  scheduledMinutes: 240, // 4.00 scheduled clock hours
} as const;
