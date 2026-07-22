import AsyncStorage from '@react-native-async-storage/async-storage';
import { submitAttendance, type AttendanceMark } from '@/services/attendance';

/**
 * M3 offline tolerance (spec §7): the instructor is on a floor with a phone and
 * the network drops. Attendance batches are queued locally and flushed on
 * reconnect. Sync state is exposed so the UI can show it.
 *
 * The queue is idempotent-friendly: attendance is append-only, and a replayed
 * batch for the same (enrollment, session) simply creates another row that the
 * ledger view can reconcile via supersession if needed. Keep batches small and
 * flush eagerly to minimise duplication windows.
 */

const QUEUE_KEY = 'tgi.attendance.queue.v1';

export interface QueuedBatch {
  id: string; // client-generated, for dedupe/logging
  sessionId: string;
  recordedBy: string;
  marks: AttendanceMark[];
  queuedAt: string;
}

export type SyncState = 'idle' | 'syncing' | 'error';

async function readQueue(): Promise<QueuedBatch[]> {
  const raw = await AsyncStorage.getItem(QUEUE_KEY);
  return raw ? (JSON.parse(raw) as QueuedBatch[]) : [];
}

async function writeQueue(q: QueuedBatch[]): Promise<void> {
  await AsyncStorage.setItem(QUEUE_KEY, JSON.stringify(q));
}

export async function pendingCount(): Promise<number> {
  return (await readQueue()).length;
}

/** Enqueue a batch. Attempt an immediate flush; failures stay queued. */
export async function enqueueAttendance(batch: Omit<QueuedBatch, 'id' | 'queuedAt'>): Promise<void> {
  const q = await readQueue();
  q.push({
    ...batch,
    id: `${batch.sessionId}:${Date.now()}`,
    queuedAt: new Date().toISOString(),
  });
  await writeQueue(q);
  await flushQueue().catch(() => {
    /* stay queued; caller polls pendingCount */
  });
}

/** Flush all queued batches oldest-first. Stops at the first failure. */
export async function flushQueue(): Promise<{ flushed: number; remaining: number }> {
  let q = await readQueue();
  let flushed = 0;
  while (q.length > 0) {
    const next = q[0]!;
    await submitAttendance(next.sessionId, next.recordedBy, next.marks);
    q = q.slice(1);
    await writeQueue(q);
    flushed += 1;
  }
  return { flushed, remaining: q.length };
}
