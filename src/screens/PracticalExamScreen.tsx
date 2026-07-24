import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Switch, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import { getPracticalCategories, scorePracticalExam } from '@/services/assessments';
import type { AssessmentAttempt, PracticalCategory } from '@/types/database';

/**
 * M-Ch25 — Final Practical Examination (instructor). Score each of the nine
 * categories 1..5; the composite (>= 80% to graduate) is computed by the server.
 * Any automatic-failure condition fails the exam regardless of composite.
 */
interface Props {
  programId: string;
  enrollmentId: string;
  assessmentId: string;
  proctorId: string;
}

const SCALE = [
  { v: 5, label: 'Exceptional' }, { v: 4, label: 'Meets Standard' },
  { v: 3, label: 'Needs Improvement' }, { v: 2, label: 'Unsatisfactory' }, { v: 1, label: 'Fail' },
];

export default function PracticalExamScreen({ programId, enrollmentId, assessmentId, proctorId }: Props) {
  const [cats, setCats] = useState<PracticalCategory[]>([]);
  const [scores, setScores] = useState<Record<string, number>>({});
  const [autoFail, setAutoFail] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<AssessmentAttempt | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const c = await getPracticalCategories(programId);
      setCats(c);
      setScores(Object.fromEntries(c.map((x) => [x.key, 4]))); // default "Meets Standard"
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [programId]);

  useEffect(() => { void load(); }, [load]);

  const composite = cats.length
    ? Math.round((cats.reduce((s, c) => s + (scores[c.key] ?? 0), 0) / (5 * cats.length)) * 10000) / 100
    : 0;
  const wouldPass = composite >= 80 && !autoFail;

  async function submit() {
    setBusy(true); setError(null);
    try {
      const att = await scorePracticalExam({
        enrollmentId, assessmentId, attemptNumber: 1, proctoredBy: proctorId,
        scores, autoFail,
      });
      setResult(att);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  if (result) {
    const pass = result.passed === true;
    return (
      <View style={[s.screen, s.center]}>
        <View style={[s.resultCard, { borderColor: pass ? theme.color.felt : theme.color.danger }]}>
          <Text style={s.subtle}>Composite (computed)</Text>
          <Text style={[s.big, { color: pass ? theme.color.felt : theme.color.danger }]}>{result.score}%</Text>
          <Text style={[s.verdict, { color: pass ? theme.color.felt : theme.color.danger }]}>
            {pass ? 'PASS' : 'FAIL'}
          </Text>
          {!pass && autoFail && <Text style={s.subtle}>Automatic-failure condition recorded.</Text>}
        </View>
      </View>
    );
  }

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Final Practical Examination</Text>
      <Text style={s.subtle}>Score each category 1–5 · graduate at ≥ 80% composite</Text>
      {error && <Text style={s.error}>{error}</Text>}

      {cats.map((c) => (
        <View key={c.key} style={s.card}>
          <Text style={s.catName}>{c.name}</Text>
          <Text style={s.standard}>{c.standard}</Text>
          <View style={s.scaleRow}>
            {SCALE.map((sc) => {
              const on = scores[c.key] === sc.v;
              return (
                <Pressable key={sc.v} style={[s.scaleBtn, on && s.scaleOn]} onPress={() => setScores((p) => ({ ...p, [c.key]: sc.v }))}>
                  <Text style={[s.scaleV, on && s.scaleVOn]}>{sc.v}</Text>
                </Pressable>
              );
            })}
          </View>
          <Text style={s.scaleLabel}>{SCALE.find((x) => x.v === scores[c.key])?.label ?? ''}</Text>
        </View>
      ))}

      <View style={[s.card, autoFail && { borderColor: theme.color.danger, borderWidth: 2 }]}>
        <View style={s.afRow}>
          <View style={{ flex: 1 }}>
            <Text style={s.catName}>Automatic-failure condition</Text>
            <Text style={s.standard}>Payout errors, misread showdowns, major game-protection failure, unprofessional conduct, or dishonesty.</Text>
          </View>
          <Switch value={autoFail} onValueChange={setAutoFail} trackColor={{ true: theme.color.danger, false: theme.color.border }} />
        </View>
      </View>

      <View style={s.previewRow}>
        <Text style={s.previewLabel}>Composite</Text>
        <Text style={[s.previewVal, { color: wouldPass ? theme.color.felt : theme.color.danger }]}>
          {composite}% · {wouldPass ? 'pass' : 'fail'}
        </Text>
      </View>

      <Pressable style={[s.primary, busy && { opacity: 0.6 }]} disabled={busy} onPress={submit}>
        <Text style={s.primaryText}>{busy ? 'Recording…' : 'Record practical result'}</Text>
      </Pressable>
    </ScrollView>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 22, fontWeight: '800', color: theme.color.felt },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(1) },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginTop: theme.space(1.5) },
  catName: { fontWeight: '700', color: theme.color.text },
  standard: { color: theme.color.subtle, fontSize: 12, marginTop: 2 },
  scaleRow: { flexDirection: 'row', gap: 8, marginTop: theme.space(1.5) },
  scaleBtn: { flex: 1, height: 42, borderRadius: 8, borderWidth: 1, borderColor: theme.color.border, alignItems: 'center', justifyContent: 'center' },
  scaleOn: { backgroundColor: theme.color.felt, borderColor: theme.color.felt },
  scaleV: { fontWeight: '800', color: theme.color.text },
  scaleVOn: { color: '#fff' },
  scaleLabel: { color: theme.color.subtle, fontSize: 12, marginTop: 6, textAlign: 'right' },
  afRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(1) },
  previewRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: theme.space(2), marginBottom: theme.space(1) },
  previewLabel: { color: theme.color.subtle, fontWeight: '700' },
  previewVal: { fontWeight: '900', fontSize: 18 },
  primary: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  primaryText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  resultCard: { borderWidth: 2, borderRadius: theme.radius, padding: theme.space(3), alignItems: 'center', margin: theme.space(2) },
  big: { fontSize: 46, fontWeight: '900' },
  verdict: { fontSize: 20, fontWeight: '800' },
  error: { color: theme.color.danger, marginTop: theme.space(1) },
});
