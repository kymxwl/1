import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { theme } from '@/theme';
import {
  getAssessment, getAssessmentQuestions, beginAttempt, submitAndGrade,
  type AttemptSession,
} from '@/services/assessments';
import { getAttemptFeedback, type QuestionFeedback } from '@/services/practice';
import type { Assessment, AssessmentAttempt, QuestionPublic } from '@/types/database';

/**
 * M4 — Practice quiz (non-secure). The student answers, the server grades
 * (grade_attempt), and immediate feedback with explanations is fetched from
 * attempt_feedback — which only returns the key post-submission for non-secure
 * assessments.
 */
interface Props {
  assessmentId: string;
  enrollmentId: string;
}

type Phase = 'intro' | 'taking' | 'results';

export default function QuizScreen({ assessmentId, enrollmentId }: Props) {
  const [assessment, setAssessment] = useState<Assessment | null>(null);
  const [questions, setQuestions] = useState<QuestionPublic[]>([]);
  const [phase, setPhase] = useState<Phase>('intro');
  const [session, setSession] = useState<AttemptSession | null>(null);
  const [responses, setResponses] = useState<Record<string, string>>({});
  const [graded, setGraded] = useState<AssessmentAttempt | null>(null);
  const [feedback, setFeedback] = useState<QuestionFeedback[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([getAssessment(assessmentId), getAssessmentQuestions(assessmentId)])
      .then(([a, q]) => { setAssessment(a); setQuestions(q); })
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, [assessmentId]);

  const start = useCallback(async () => {
    if (!assessment) return;
    setBusy(true); setError(null);
    try {
      const sess = await beginAttempt({ enrollmentId, assessment });
      setSession(sess); setPhase('taking');
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }, [assessment, enrollmentId]);

  async function submit() {
    if (!session) return;
    setBusy(true); setError(null);
    try {
      const g = await submitAndGrade(session, responses);
      setGraded(g);
      setFeedback(await getAttemptFeedback(g.id));
      setPhase('results');
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); }
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;
  if (!assessment) return <View style={[s.screen, s.center]}><Text style={s.error}>Quiz not found.</Text></View>;

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>{assessment.title}</Text>
      {error && <Text style={s.error}>{error}</Text>}

      {phase === 'intro' && (
        <View style={s.card}>
          <Text style={s.subtle}>
            {assessment.question_count} questions · pass ≥ {assessment.passing_score}% · practice (not proctored)
          </Text>
          <Pressable style={[s.primary, busy && { opacity: 0.6 }]} disabled={busy} onPress={start}>
            <Text style={s.primaryText}>{busy ? 'Starting…' : 'Start quiz'}</Text>
          </Pressable>
        </View>
      )}

      {phase === 'taking' && (
        <View>
          {questions.map((q, i) => (
            <View key={q.id} style={s.card}>
              <Text style={s.stem}>{i + 1}. {q.stem}</Text>
              {q.type === 'short_answer' ? (
                <TextInput
                  style={s.input}
                  value={responses[q.id] ?? ''}
                  onChangeText={(t) => setResponses((p) => ({ ...p, [q.id]: t }))}
                  placeholder="Your answer"
                  placeholderTextColor={theme.color.subtle}
                />
              ) : (
                (q.options as { key: string; text: string }[]).map((opt) => {
                  const on = responses[q.id] === opt.key;
                  return (
                    <Pressable key={opt.key} style={[s.opt, on && s.optOn]} onPress={() => setResponses((p) => ({ ...p, [q.id]: opt.key }))}>
                      <Text style={[s.optText, on && s.optTextOn]}>{opt.text}</Text>
                    </Pressable>
                  );
                })
              )}
            </View>
          ))}
          <Pressable style={[s.primary, busy && { opacity: 0.6 }]} disabled={busy} onPress={submit}>
            <Text style={s.primaryText}>{busy ? 'Grading…' : 'Submit'}</Text>
          </Pressable>
        </View>
      )}

      {phase === 'results' && graded && (
        <View>
          <View style={[s.card, s.scoreCard, { borderColor: graded.passed ? theme.color.felt : theme.color.danger }]}>
            <Text style={[s.score, { color: graded.passed ? theme.color.felt : theme.color.danger }]}>{graded.score}%</Text>
            <Text style={[s.verdict, { color: graded.passed ? theme.color.felt : theme.color.danger }]}>
              {graded.passed ? 'PASS' : 'KEEP PRACTICING'}
            </Text>
          </View>
          {feedback.map((f, i) => (
            <View key={f.question_id} style={[s.card, { borderLeftWidth: 4, borderLeftColor: f.is_correct ? theme.color.felt : theme.color.danger }]}>
              <Text style={s.stem}>{i + 1}. {f.stem}</Text>
              <Text style={[s.fbTag, { color: f.is_correct ? theme.color.felt : theme.color.danger }]}>
                {f.is_correct ? '✓ Correct' : '✗ Incorrect'}
              </Text>
              {f.explanation && <Text style={s.explain}>{f.explanation}</Text>}
            </View>
          ))}
        </View>
      )}
    </ScrollView>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 22, fontWeight: '800', color: theme.color.felt, marginBottom: theme.space(1) },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginBottom: theme.space(2) },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(2) },
  stem: { fontWeight: '700', color: theme.color.text, marginBottom: theme.space(1) },
  input: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, padding: theme.space(1.5), color: theme.color.text },
  opt: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, padding: theme.space(1.5), marginBottom: 8 },
  optOn: { borderColor: theme.color.felt, backgroundColor: '#e9f1ec' },
  optText: { color: theme.color.text },
  optTextOn: { color: theme.color.felt, fontWeight: '700' },
  primary: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  primaryText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  scoreCard: { alignItems: 'center', borderWidth: 2 },
  score: { fontSize: 44, fontWeight: '900' },
  verdict: { fontSize: 18, fontWeight: '800' },
  fbTag: { fontWeight: '800', marginBottom: 4 },
  explain: { color: theme.color.subtle },
  error: { color: theme.color.danger, marginBottom: theme.space(1) },
});
