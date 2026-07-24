import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { theme } from '@/theme';
import {
  getAssessment, getAssessmentQuestions, beginAttempt, submitAndGrade,
  submitForManualGrading, type AttemptSession,
} from '@/services/assessments';
import type { Assessment, AssessmentAttempt, QuestionPublic } from '@/types/database';

/**
 * M5 — Secure Exam delivery. Questions come from question_bank_public (no answer
 * key in the payload). A proctor must sign off before a secure exam begins;
 * grading runs server-side via grade_attempt(). The client never sees or
 * computes a score.
 */
interface Props {
  assessmentId: string;
  enrollmentId: string;
  proctorId: string;       // signed-in instructor/admin acting as proctor
  proctorName: string;
}

type Phase = 'signoff' | 'in_progress' | 'submitted';

export default function SecureExamScreen({
  assessmentId, enrollmentId, proctorId, proctorName,
}: Props) {
  const [assessment, setAssessment] = useState<Assessment | null>(null);
  const [questions, setQuestions] = useState<QuestionPublic[]>([]);
  const [phase, setPhase] = useState<Phase>('signoff');
  const [session, setSession] = useState<AttemptSession | null>(null);
  const [responses, setResponses] = useState<Record<string, string>>({});
  const [result, setResult] = useState<AssessmentAttempt | null>(null);
  const [secondsLeft, setSecondsLeft] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmed, setConfirmed] = useState(false);
  const submitRef = useRef<() => void>(() => {});

  useEffect(() => {
    Promise.all([getAssessment(assessmentId), getAssessmentQuestions(assessmentId)])
      .then(([a, q]) => { setAssessment(a); setQuestions(q); })
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, [assessmentId]);

  const doSubmit = useCallback(async () => {
    if (!session) return;
    setBusy(true);
    setError(null);
    try {
      if (assessment?.grading === 'manual') {
        // Instructor-graded (e.g. Appendix L): submit responses, no score yet.
        const submitted = await submitForManualGrading(session, responses);
        setResult(submitted);
      } else {
        const graded = await submitAndGrade(session, responses);
        setResult(graded);
      }
      setPhase('submitted');
      setSecondsLeft(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }, [session, responses, assessment]);
  submitRef.current = doSubmit;

  // Countdown; auto-submit at zero.
  useEffect(() => {
    if (phase !== 'in_progress' || secondsLeft === null) return;
    if (secondsLeft <= 0) { submitRef.current(); return; }
    const t = setTimeout(() => setSecondsLeft((s) => (s === null ? null : s - 1)), 1000);
    return () => clearTimeout(t);
  }, [phase, secondsLeft]);

  async function begin() {
    if (!assessment) return;
    setBusy(true);
    setError(null);
    try {
      const sess = await beginAttempt({ enrollmentId, assessment, proctoredBy: proctorId });
      setSession(sess);
      setPhase('in_progress');
      if (assessment.time_limit_minutes) setSecondsLeft(assessment.time_limit_minutes * 60);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;
  if (!assessment) return <View style={[s.screen, s.center]}><Text style={s.error}>Assessment not found.</Text></View>;

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>{assessment.title}</Text>
      <Text style={s.subtle}>
        {assessment.question_count} questions · pass ≥ {assessment.passing_score}%
        {assessment.time_limit_minutes ? ` · ${assessment.time_limit_minutes} min` : ''}
        {assessment.is_secure ? ' · SECURE' : ''}
      </Text>

      {error && <Text style={s.error}>{error}</Text>}

      {phase === 'signoff' && (
        <View style={s.card}>
          <Text style={s.h2}>Proctor sign-off</Text>
          <Text style={s.subtle}>
            {assessment.is_secure
              ? 'This is a secure exam. It cannot start or be graded without a proctor.'
              : 'Confirm you are supervising this attempt.'}
          </Text>
          <View style={s.signRow}>
            <Text style={s.signLabel}>Proctor</Text>
            <Text style={s.signName}>{proctorName}</Text>
          </View>
          <Pressable style={s.checkbox} onPress={() => setConfirmed((c) => !c)}>
            <View style={[s.box, confirmed && s.boxOn]}>{confirmed && <Text style={s.boxTick}>✓</Text>}</View>
            <Text style={s.checkboxText}>I am present and proctoring this exam.</Text>
          </Pressable>
          <Pressable
            style={[s.primary, (!confirmed || busy) && { opacity: 0.5 }]}
            disabled={!confirmed || busy}
            onPress={begin}
          >
            <Text style={s.primaryText}>{busy ? 'Starting…' : 'Start exam'}</Text>
          </Pressable>
        </View>
      )}

      {phase === 'in_progress' && (
        <View>
          {secondsLeft !== null && (
            <View style={s.timer}>
              <Text style={s.timerText}>{fmt(secondsLeft)}</Text>
            </View>
          )}
          {questions.map((q, i) => (
            <View key={q.id} style={s.card}>
              <Text style={s.qStem}>{i + 1}. {q.stem}</Text>
              {q.type === 'short_answer' ? (
                <TextInput
                  style={s.shortAnswer}
                  value={responses[q.id] ?? ''}
                  onChangeText={(t) => setResponses((p) => ({ ...p, [q.id]: t }))}
                  placeholder="Your answer"
                  placeholderTextColor={theme.color.subtle}
                />
              ) : (
                (q.options as { key: string; text: string }[]).map((opt) => {
                  const selected = responses[q.id] === opt.key;
                  return (
                    <Pressable
                      key={opt.key}
                      style={[s.option, selected && s.optionOn]}
                      onPress={() => setResponses((p) => ({ ...p, [q.id]: opt.key }))}
                    >
                      <Text style={[s.optionText, selected && s.optionTextOn]}>{opt.text}</Text>
                    </Pressable>
                  );
                })
              )}
            </View>
          ))}
          <Pressable style={[s.primary, busy && { opacity: 0.6 }]} disabled={busy} onPress={doSubmit}>
            <Text style={s.primaryText}>{busy ? 'Submitting…' : 'Submit exam'}</Text>
          </Pressable>
        </View>
      )}

      {phase === 'submitted' && result && result.score == null && (
        <View style={[s.card, s.resultCard, { borderColor: theme.color.brass }]}>
          <Text style={s.verdict}>Submitted</Text>
          <Text style={s.subtle}>Awaiting instructor grading.</Text>
        </View>
      )}
      {phase === 'submitted' && result && result.score != null && (
        <View style={[s.card, s.resultCard, { borderColor: result.passed ? theme.color.felt : theme.color.danger }]}>
          <Text style={s.subtle}>Result (graded server-side)</Text>
          <Text style={[s.score, { color: result.passed ? theme.color.felt : theme.color.danger }]}>
            {result.score}%
          </Text>
          <Text style={[s.verdict, { color: result.passed ? theme.color.felt : theme.color.danger }]}>
            {result.passed ? 'PASS' : 'DID NOT PASS'}
          </Text>
        </View>
      )}
    </ScrollView>
  );
}

function fmt(total: number): string {
  const m = Math.floor(total / 60);
  const sec = total % 60;
  return `${m}:${sec.toString().padStart(2, '0')}`;
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 22, fontWeight: '800', color: theme.color.felt },
  h2: { fontSize: 17, fontWeight: '700', color: theme.color.text, marginBottom: theme.space(1) },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(2) },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, padding: theme.space(2), borderWidth: 1, borderColor: theme.color.border, marginBottom: theme.space(2) },
  signRow: { flexDirection: 'row', justifyContent: 'space-between', marginVertical: theme.space(1.5) },
  signLabel: { color: theme.color.subtle },
  signName: { fontWeight: '700', color: theme.color.text },
  checkbox: { flexDirection: 'row', alignItems: 'center', gap: theme.space(1), marginBottom: theme.space(2) },
  box: { width: 24, height: 24, borderRadius: 6, borderWidth: 2, borderColor: theme.color.felt, alignItems: 'center', justifyContent: 'center' },
  boxOn: { backgroundColor: theme.color.felt },
  boxTick: { color: '#fff', fontWeight: '900' },
  checkboxText: { flex: 1, color: theme.color.text },
  primary: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  primaryText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  timer: { alignSelf: 'center', backgroundColor: theme.color.felt, borderRadius: 999, paddingHorizontal: theme.space(3), paddingVertical: theme.space(1), marginBottom: theme.space(2) },
  timerText: { color: theme.color.brass, fontWeight: '900', fontSize: 22, letterSpacing: 1 },
  qStem: { fontWeight: '700', color: theme.color.text, marginBottom: theme.space(1.5) },
  option: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, padding: theme.space(1.5), marginBottom: 8 },
  optionOn: { borderColor: theme.color.felt, backgroundColor: '#e9f1ec' },
  optionText: { color: theme.color.text },
  optionTextOn: { color: theme.color.felt, fontWeight: '700' },
  shortAnswer: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, padding: theme.space(1.5), color: theme.color.text },
  resultCard: { alignItems: 'center', borderWidth: 2 },
  score: { fontSize: 48, fontWeight: '900' },
  verdict: { fontSize: 20, fontWeight: '800' },
  error: { color: theme.color.danger, marginBottom: theme.space(1) },
});
