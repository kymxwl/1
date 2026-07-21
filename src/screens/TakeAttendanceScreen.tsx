import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, FlatList, Pressable, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { theme } from '@/theme';
import { supabase } from '@/lib/supabase';
import type { AttendanceStatus } from '@/types/database';
import { enqueueAttendance, flushQueue, pendingCount } from '@/services/offlineQueue';
import type { AttendanceMark } from '@/services/attendance';

/**
 * M3 — Take Attendance. Target: a full class in under 60 seconds, on a phone,
 * tolerant of a dropped network. Marks are queued locally and flushed on submit;
 * the pending count is always visible.
 */
interface Props {
  sessionId: string;
  cohortId: string;
  instructorProfileId: string;
  defaultMinutes: number; // = scheduled_clock_hours * 60
}

interface Row {
  enrollmentId: string;
  name: string;
  status: AttendanceStatus;
  minutes: number;
}

const CYCLE: AttendanceStatus[] = ['present', 'tardy', 'left_early', 'excused', 'absent'];

export default function TakeAttendanceScreen({
  sessionId, cohortId, instructorProfileId, defaultMinutes,
}: Props) {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState(0);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    // Roster = enrollments in this cohort (RLS scopes to instructor's cohorts).
    const { data, error } = await supabase
      .from('enrollments')
      .select('id, student_id, students(first_name, last_name)')
      .eq('cohort_id', cohortId)
      .in('status', ['active', 'enrolled']);
    if (!error && data) {
      setRows(
        (data as unknown as RosterRow[]).map((e) => ({
          enrollmentId: e.id,
          name: `${e.students?.first_name ?? ''} ${e.students?.last_name ?? ''}`.trim(),
          status: 'present',
          minutes: defaultMinutes,
        })),
      );
    }
    setPending(await pendingCount());
    setLoading(false);
  }, [cohortId, defaultMinutes]);

  useEffect(() => { void load(); }, [load]);

  const allPresent = useMemo(() => rows.every((r) => r.status === 'present'), [rows]);

  function cycleStatus(enrollmentId: string) {
    setRows((prev) =>
      prev.map((r) => {
        if (r.enrollmentId !== enrollmentId) return r;
        const next = CYCLE[(CYCLE.indexOf(r.status) + 1) % CYCLE.length]!;
        const minutes = next === 'absent' || next === 'excused' ? 0
          : next === 'present' ? defaultMinutes : r.minutes;
        return { ...r, status: next, minutes };
      }),
    );
  }

  function setMinutes(enrollmentId: string, minutes: number) {
    setRows((prev) => prev.map((r) => (r.enrollmentId === enrollmentId ? { ...r, minutes } : r)));
  }

  async function submit() {
    setSaving(true);
    const marks: AttendanceMark[] = rows.map((r) => ({
      enrollmentId: r.enrollmentId,
      status: r.status,
      minutesPresent: r.minutes,
    }));
    // Queue first (durable), then flush. If offline, it stays queued.
    await enqueueAttendance({ sessionId, recordedBy: instructorProfileId, marks });
    try {
      await flushQueue();
    } catch {
      /* remains queued; shown in the banner */
    }
    setPending(await pendingCount());
    setSaving(false);
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  return (
    <View style={s.screen}>
      {pending > 0 && (
        <Pressable style={s.banner} onPress={() => flushQueue().then(async () => setPending(await pendingCount()))}>
          <Text style={s.bannerText}>
            {pending} batch(es) waiting to sync — tap to retry
          </Text>
        </Pressable>
      )}

      <View style={s.toolbar}>
        <Pressable
          style={s.bulkBtn}
          onPress={() => setRows((prev) => prev.map((r) => ({ ...r, status: 'present', minutes: defaultMinutes })))}
        >
          <Text style={s.bulkText}>{allPresent ? 'All present ✓' : 'Mark all present'}</Text>
        </Pressable>
      </View>

      <FlatList
        data={rows}
        keyExtractor={(r) => r.enrollmentId}
        contentContainerStyle={{ padding: theme.space(1) }}
        renderItem={({ item }) => (
          <View style={s.row}>
            <Text style={s.name} numberOfLines={1}>{item.name || 'Student'}</Text>
            <TextInput
              style={s.minutes}
              keyboardType="number-pad"
              value={String(item.minutes)}
              onChangeText={(t) => setMinutes(item.enrollmentId, Number(t.replace(/\D/g, '') || 0))}
              editable={item.status !== 'absent' && item.status !== 'excused'}
            />
            <Pressable style={[s.statusBtn, statusStyle(item.status)]} onPress={() => cycleStatus(item.enrollmentId)}>
              <Text style={s.statusText}>{shortStatus(item.status)}</Text>
            </Pressable>
          </View>
        )}
      />

      <Pressable style={[s.submit, saving && { opacity: 0.6 }]} disabled={saving} onPress={submit}>
        <Text style={s.submitText}>{saving ? 'Saving…' : `Submit attendance (${rows.length})`}</Text>
      </Pressable>
    </View>
  );
}

interface RosterRow {
  id: string;
  student_id: string;
  students?: { first_name?: string; last_name?: string } | null;
}

function shortStatus(st: AttendanceStatus): string {
  return { present: 'P', tardy: 'T', left_early: 'LE', excused: 'E', absent: 'A' }[st];
}
function statusStyle(st: AttendanceStatus) {
  const map: Record<AttendanceStatus, string> = {
    present: theme.color.felt, tardy: theme.color.brass, left_early: '#8a6d1f',
    excused: theme.color.subtle, absent: theme.color.danger,
  };
  return { backgroundColor: map[st] };
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  banner: { backgroundColor: theme.color.brass, padding: theme.space(1.5) },
  bannerText: { color: '#3a2f0a', fontWeight: '700', textAlign: 'center' },
  toolbar: { padding: theme.space(1), flexDirection: 'row', justifyContent: 'flex-end' },
  bulkBtn: { backgroundColor: theme.color.feltLight, paddingHorizontal: theme.space(2), paddingVertical: theme.space(1), borderRadius: 999 },
  bulkText: { color: '#fff', fontWeight: '700' },
  row: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: theme.color.card,
    borderRadius: theme.radius, padding: theme.space(1.5), marginVertical: 4,
    borderWidth: 1, borderColor: theme.color.border, gap: theme.space(1),
  },
  name: { flex: 1, fontWeight: '600', color: theme.color.text },
  minutes: {
    width: 56, textAlign: 'center', borderWidth: 1, borderColor: theme.color.border,
    borderRadius: 8, paddingVertical: 6, color: theme.color.text,
  },
  statusBtn: { width: 44, height: 40, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  statusText: { color: '#fff', fontWeight: '800' },
  submit: { backgroundColor: theme.color.felt, padding: theme.space(2), alignItems: 'center' },
  submitText: { color: '#fff', fontWeight: '800', fontSize: 16 },
});
