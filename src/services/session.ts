import { supabase } from '@/lib/supabase';
import type { AppRole, Enrollment } from '@/types/database';

/** Auth + "who am I / what am I enrolled in" helpers used to bootstrap screens. */

export async function getRole(): Promise<AppRole | null> {
  const { data, error } = await supabase.rpc('current_app_role');
  if (error) return null;
  return data ?? null;
}

export async function signInWithEmail(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  await supabase.auth.signOut();
}

/**
 * Admin: assign a role to a user (instructor/admin/student). Enforced
 * admin-only by the set_user_role() DB function regardless of the client.
 */
export async function setUserRole(userId: string, role: AppRole): Promise<void> {
  const { error } = await supabase.rpc('set_user_role', {
    p_user_id: userId,
    p_role: role,
  });
  if (error) throw error;
}

/** The signed-in student's active enrollment (for the Passport screen). */
export async function getMyActiveEnrollment(): Promise<Enrollment | null> {
  const { data, error } = await supabase
    .from('enrollments')
    .select('*')
    .in('status', ['active', 'enrolled'])
    .order('enrolled_at', { ascending: false })
    .limit(1)
    .maybeSingle(); // RLS already scopes to the caller's own enrollments
  if (error) throw error;
  return data;
}
