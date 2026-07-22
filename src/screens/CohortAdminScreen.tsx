import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { theme } from '@/theme';
import {
  listCohorts, createCohort, generateSessions, getCohortSessions,
  getRoster, listEnrollableStudents, enrollStudent,
  type CohortRow, type RosterMember, type EnrollableStudent,
} from '@/services/cohorts';
import type { Session } from '@/types/database';

/**
 * M2 — Cohorts, Enrollment & Sessions (admin). Create a cohort, generate its
 * session calendar from a weekly template, and enrol students from existing
 * intake records. Done-when: create 2026-A, generate its calendar, enrol.
 */
const WEEKDAYS = [
  { dow: 1, label: 'Mon' }, { dow: 2, label: 'Tue' }, { dow: 3, label: 'Wed' },
  { dow: 4, label: 'Thu' }, { dow: 5, label: 'Fri' }, { dow: 6, label: 'Sat' },
  { dow: 7, label: 'Sun' },
];

export default function CohortAdminScreen({ programId }: { programId: string }) {
  const [cohorts, setCohorts] = useState<CohortRow[]>([]);
  const [selected, setSelected] = useState<CohortRow | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [roster, setRoster] = useState<RosterMember[]>([]);
  const [eligible, setEligible] = useState<EnrollableStudent[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // New-cohort form
  const [showNew, setShowNew] = useState(false);
  const [name, setName] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  // Schedule template
  const [weekdays, setWeekdays] = useState<number[]>([1, 2, 3, 4, 5]);
  const [startTime, setStartTime] = useState('09:00');
  const [endTime, setEndTime] = useState('13:00');
  const [clockHours, setClockHours] = useState('4');

  const loadCohorts = useCallback(async () => {
    setLoading(true);
    try {
      const cs = await listCohorts(programId);
      setCohorts(cs);
      setSelected((prev) => prev ?? cs[0] ?? null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [programId]);

  const loadDetail = useCallback(async (cohortId: string) => {
    try {
      const [ss, rs, el] = await Promise.all([
        getCohortSessions(cohortId), getRoster(cohortId), listEnrollableStudents(cohortId),
      ]);
      setSessions(ss); setRoster(rs); setEligible(el);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, []);

  useEffect(() => { void loadCohorts(); }, [loadCohorts]);
  useEffect(() => { if (selected) void loadDetail(selected.id); }, [selected, loadDetail]);

  async function onCreate() {
    setBusy(true); setError(null); setMsg(null);
    try {
      const c = await createCohort({ programId, name, startDate, endDate });
      setName(''); setStartDate(''); setEndDate(''); setShowNew(false);
      await loadCohorts();
      setSelected(c);
      setMsg(`Created cohort ${c.name}.`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  async function onGenerate() {
    if (!selected) return;
    setBusy(true); setError(null); setMsg(null);
    try {
      const n = await generateSessions(selected.id, {
        weekdays, startTime, endTime, clockHours: Number(clockHours),
      });
      await loadDetail(selected.id);
      setMsg(`Generated ${n} session(s).`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  async function onEnroll(s: EnrollableStudent) {
    if (!selected) return;
    setBusy(true); setError(null); setMsg(null);
    try {
      await enrollStudent({ studentId: s.studentId, cohortId: selected.id, agreementId: s.agreementId });
      await loadDetail(selected.id);
      setMsg(`Enrolled ${s.name}.`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  function toggleDay(dow: number) {
    setWeekdays((p) => (p.includes(dow) ? p.filter((d) => d !== dow) : [...p, dow].sort()));
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Cohorts</Text>
      {error && <Text style={s.error}>{error}</Text>}
      {msg && <Text style={s.ok}>{msg}</Text>}

      <View style={s.chipRow}>
        {cohorts.map((c) => (
          <Pressable key={c.id} style={[s.cohortChip, selected?.id === c.id && s.cohortChipOn]} onPress={() => setSelected(c)}>
            <Text style={[s.cohortChipText, selected?.id === c.id && s.cohortChipTextOn]}>{c.name}</Text>
          </Pressable>
        ))}
        <Pressable style={s.newChip} onPress={() => setShowNew((v) => !v)}>
          <Text style={s.newChipText}>{showNew ? '×' : '+ New'}</Text>
        </Pressable>
      </View>

      {showNew && (
        <View style={s.card}>
          <Text style={s.label}>New cohort</Text>
          <Field placeholder="Name (e.g. 2026-B)" value={name} onChangeText={setName} />
          <Field placeholder="Start date (YYYY-MM-DD)" value={startDate} onChangeText={setStartDate} />
          <Field placeholder="End date (YYYY-MM-DD)" value={endDate} onChangeText={setEndDate} />
          <Pressable
            style={[s.primary, (busy || !name || !startDate || !endDate) && { opacity: 0.5 }]}
            disabled={busy || !name || !startDate || !endDate}
            onPress={onCreate}
          >
            <Text style={s.primaryText}>Create cohort</Text>
          </Pressable>
        </View>
      )}

      {selected && (
        <>
          <View style={s.card}>
            <Text style={s.label}>{selected.name} · {selected.start_date} → {selected.end_date}</Text>
            <Text style={s.subtle}>{sessions.length} session(s) scheduled · {roster.length} enrolled</Text>
          </View>

          <View style={s.card}>
            <Text style={s.label}>Generate session calendar</Text>
            <View style={s.dayRow}>
              {WEEKDAYS.map((w) => (
                <Pressable key={w.dow} style={[s.day, weekdays.includes(w.dow) && s.dayOn]} onPress={() => toggleDay(w.dow)}>
                  <Text style={[s.dayText, weekdays.includes(w.dow) && s.dayTextOn]}>{w.label}</Text>
                </Pressable>
              ))}
            </View>
            <View style={s.timeRow}>
              <Field small placeholder="09:00" value={startTime} onChangeText={setStartTime} />
              <Text style={s.dash}>–</Text>
              <Field small placeholder="13:00" value={endTime} onChangeText={setEndTime} />
              <Field small placeholder="hrs" value={clockHours} onChangeText={setClockHours} keyboardType="decimal-pad" />
            </View>
            <Pressable style={[s.primary, busy && { opacity: 0.6 }]} disabled={busy} onPress={onGenerate}>
              <Text style={s.primaryText}>{busy ? 'Generating…' : 'Generate calendar'}</Text>
            </Pressable>
          </View>

          <View style={s.card}>
            <Text style={s.label}>Roster ({roster.length})</Text>
            {roster.length === 0 && <Text style={s.subtle}>No students enrolled yet.</Text>}
            {roster.map((m) => (
              <View key={m.enrollmentId} style={s.memberRow}>
                <Text style={s.memberName}>{m.name}</Text>
                <Text style={s.memberStatus}>{m.status}</Text>
              </View>
            ))}
          </View>

          <View style={s.card}>
            <Text style={s.label}>Eligible to enrol ({eligible.length})</Text>
            {eligible.length === 0 && <Text style={s.subtle}>No eligible intake records (needs signed packet + approved payment).</Text>}
            {eligible.map((e) => (
              <View key={e.studentId} style={s.memberRow}>
                <Text style={s.memberName}>{e.name}</Text>
                <Pressable style={s.enrolBtn} disabled={busy} onPress={() => onEnroll(e)}>
                  <Text style={s.enrolText}>Enrol</Text>
                </Pressable>
              </View>
            ))}
          </View>
        </>
      )}
    </ScrollView>
  );
}

function Field({
  small, ...props
}: React.ComponentProps<typeof TextInput> & { small?: boolean }) {
  return (
    <TextInput
      {...props}
      placeholderTextColor={theme.color.subtle}
      style={[s.input, small && s.inputSmall]}
    />
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 24, fontWeight: '800', color: theme.color.felt, marginBottom: theme.space(1) },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: theme.space(2) },
  cohortChip: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8, backgroundColor: theme.color.card },
  cohortChipOn: { backgroundColor: theme.color.felt, borderColor: theme.color.felt },
  cohortChipText: { color: theme.color.text, fontWeight: '700' },
  cohortChipTextOn: { color: '#fff' },
  newChip: { borderWidth: 1, borderColor: theme.color.brass, borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8 },
  newChipText: { color: theme.color.brass, fontWeight: '800' },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginBottom: theme.space(2) },
  label: { fontWeight: '700', color: theme.color.text, marginBottom: theme.space(1) },
  subtle: { color: theme.color.subtle },
  input: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, padding: theme.space(1.5), color: theme.color.text, marginBottom: theme.space(1) },
  inputSmall: { flex: 1, marginBottom: 0, textAlign: 'center' },
  dayRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginBottom: theme.space(1.5) },
  day: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8 },
  dayOn: { backgroundColor: theme.color.felt, borderColor: theme.color.felt },
  dayText: { color: theme.color.text, fontWeight: '600' },
  dayTextOn: { color: '#fff' },
  timeRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: theme.space(1.5) },
  dash: { color: theme.color.subtle, fontWeight: '800' },
  primary: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(1.5), alignItems: 'center' },
  primaryText: { color: '#fff', fontWeight: '800' },
  memberRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: theme.space(1), borderTopWidth: 1, borderTopColor: theme.color.border },
  memberName: { color: theme.color.text, fontWeight: '600', flex: 1 },
  memberStatus: { color: theme.color.subtle },
  enrolBtn: { backgroundColor: theme.color.brass, borderRadius: 999, paddingHorizontal: 14, paddingVertical: 6 },
  enrolText: { color: '#3a2f0a', fontWeight: '800' },
  ok: { color: theme.color.felt, fontWeight: '600', marginBottom: theme.space(1) },
  error: { color: theme.color.danger, marginBottom: theme.space(1) },
});
