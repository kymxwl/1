import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import {
  getUngradedAttempts, getAttemptForGrading, gradeWrittenAttempt,
  type GradingItem,
} from '@/services/assessments';
import type { AssessmentAttempt } from '@/types/database';

/**
 * Instructor grading for manual (essay) exams — the Appendix L written final.
 * Lists submitted-but-ungraded attempts; opening one shows each question with
 * the student's response and a correct/incorrect toggle. The score is computed
 * server-side from the marks (grade_written_attempt) — never typed.
 */
export default function WrittenGradingScreen() {
  const [queue, setQueue] = useState<AssessmentAttempt[]>([]);
  const [open, setOpen] = useState<AssessmentAttempt | null>(null);
  const [items, setItems] = useState<GradingItem[]>([]);
  const [marks, setMarks] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [doneScore, setDoneScore] = useState<number | null>(null);

  const loadQueue = useCallback(async () => {
    setLoading(true);
    try {
      setQueue(await getUngradedAttempts());
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void loadQueue(); }, [loadQueue]);

  async function openAttempt(a: AssessmentAttempt) {
    setBusy(true); setError(null); setDoneScore(null);
    try {
      const { items: its } = await getAttemptForGrading(a.id);
      setItems(its);
      setMarks(Object.fromEntries(its.map((i) => [i.question.id, 0])));
      setOpen(a);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  async function submit() {
    if (!open) return;
    setBusy(true); setError(null);
    try {
      const score = await gradeWrittenAttempt(open.id, marks);
      setDoneScore(score);
      await loadQueue();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  // Detail / grading view
  if (open) {
    const correct = Object.values(marks).filter((v) => v === 1).length;
    const preview = items.length ? Math.round((correct / items.length) * 10000) / 100 : 0;
    if (doneScore != null) {
      return (
        <View style={[s.screen, s.center]}>
          <View style={s.doneCard}>
            <Text style={s.subtle}>Graded (computed)</Text>
            <Text style={s.big}>{doneScore}%</Text>
            <Pressable style={s.primary} onPress={() => { setOpen(null); setDoneScore(null); }}>
              <Text style={s.primaryText}>Back to queue</Text>
            </Pressable>
          </View>
        </View>
      );
    }
    return (
      <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
        <Text style={s.back} onPress={() => setOpen(null)}>‹ Queue</Text>
        <Text style={s.h1}>Grade written exam</Text>
        <Text style={s.subtle}>Mark each answer correct or incorrect.</Text>
        {error && <Text style={s.error}>{error}</Text>}
        {items.map((it, i) => (
          <View key={it.question.id} style={s.card}>
            <Text style={s.q}>{i + 1}. {it.question.stem}</Text>
            <Text style={s.respLabel}>Student answer</Text>
            <Text style={s.resp}>{it.response ?? '— (no answer) —'}</Text>
            <View style={s.markRow}>
              <Pressable
                style={[s.mark, marks[it.question.id] === 1 && s.markCorrect]}
                onPress={() => setMarks((m) => ({ ...m, [it.question.id]: 1 }))}
              >
                <Text style={[s.markText, marks[it.question.id] === 1 && s.markTextOn]}>✓ Correct</Text>
              </Pressable>
              <Pressable
                style={[s.mark, marks[it.question.id] === 0 && s.markWrong]}
                onPress={() => setMarks((m) => ({ ...m, [it.question.id]: 0 }))}
              >
                <Text style={[s.markText, marks[it.question.id] === 0 && s.markTextOn]}>✗ Incorrect</Text>
              </Pressable>
            </View>
          </View>
        ))}
        <View style={s.previewRow}>
          <Text style={s.previewLabel}>Score preview</Text>
          <Text style={s.previewVal}>{correct}/{items.length} · {preview}%</Text>
        </View>
        <Pressable style={[s.primary, busy && { opacity: 0.6 }]} disabled={busy} onPress={submit}>
          <Text style={s.primaryText}>{busy ? 'Grading…' : 'Submit grade'}</Text>
        </Pressable>
      </ScrollView>
    );
  }

  // Queue view
  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Written exams to grade</Text>
      {error && <Text style={s.error}>{error}</Text>}
      {queue.length === 0 && <Text style={s.subtle}>Nothing awaiting grading.</Text>}
      {queue.map((a) => (
        <Pressable key={a.id} style={s.card} onPress={() => openAttempt(a)} disabled={busy}>
          <Text style={s.q}>Attempt #{a.attempt_number}</Text>
          <Text style={s.subtle}>
            Submitted {a.submitted_at ? new Date(a.submitted_at).toLocaleDateString() : '—'} · tap to grade
          </Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  back: { color: theme.color.brass, fontWeight: '700', marginBottom: theme.space(1) },
  h1: { fontSize: 22, fontWeight: '800', color: theme.color.felt },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(1) },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginTop: theme.space(1.5) },
  q: { fontWeight: '700', color: theme.color.text },
  respLabel: { color: theme.color.subtle, fontSize: 11, marginTop: theme.space(1), textTransform: 'uppercase', letterSpacing: 0.5 },
  resp: { color: theme.color.text, marginTop: 2, marginBottom: theme.space(1) },
  markRow: { flexDirection: 'row', gap: 8 },
  mark: { flex: 1, borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, paddingVertical: 10, alignItems: 'center' },
  markCorrect: { backgroundColor: theme.color.felt, borderColor: theme.color.felt },
  markWrong: { backgroundColor: theme.color.danger, borderColor: theme.color.danger },
  markText: { fontWeight: '800', color: theme.color.text },
  markTextOn: { color: '#fff' },
  previewRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: theme.space(2), marginBottom: theme.space(1) },
  previewLabel: { color: theme.color.subtle, fontWeight: '700' },
  previewVal: { fontWeight: '900', fontSize: 16, color: theme.color.felt },
  primary: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center', marginTop: theme.space(1) },
  primaryText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  doneCard: { borderWidth: 2, borderColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(3), alignItems: 'center', margin: theme.space(2) },
  big: { fontSize: 46, fontWeight: '900', color: theme.color.felt, marginBottom: theme.space(1) },
  error: { color: theme.color.danger, marginTop: theme.space(1) },
});
