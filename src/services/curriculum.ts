import { supabase } from '@/lib/supabase';
import type { Chapter, Lesson, Resource } from '@/types/database';

/** M1 — Curriculum & Content (student read-only view + admin CRUD upstream). */

export interface ChapterWithLessons extends Chapter {
  lessons: Lesson[];
  resources: Resource[];
}

/** Full course outline for a program: chapters, their lessons, and resources. */
export async function getCourseOutline(programId: string): Promise<ChapterWithLessons[]> {
  const { data: courses, error: cErr } = await supabase
    .from('courses')
    .select('id')
    .eq('program_id', programId);
  if (cErr) throw cErr;
  const courseIds = (courses ?? []).map((c) => c.id);
  if (courseIds.length === 0) return [];

  const { data: chapters, error } = await supabase
    .from('chapters')
    .select('*')
    .in('course_id', courseIds)
    .order('number', { ascending: true });
  if (error) throw error;

  const chapterIds = (chapters ?? []).map((c) => c.id);

  const [{ data: lessons }, { data: resources }] = await Promise.all([
    supabase.from('lessons').select('*').in('chapter_id', chapterIds).order('sequence'),
    supabase.from('resources').select('*').eq('owner_type', 'chapter').in('owner_id', chapterIds),
  ]);

  return (chapters ?? []).map((ch) => ({
    ...ch,
    lessons: (lessons ?? []).filter((l) => l.chapter_id === ch.id),
    // RLS already filters resources by visibility for the caller's role.
    resources: (resources ?? []).filter((r) => r.owner_id === ch.id),
  }));
}
