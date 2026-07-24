import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import { supabase } from '@/lib/supabase';
import { DEMO } from '@/demo';
import { getMyActiveEnrollment } from '@/services/session';
import FlashcardScreen from '@/screens/FlashcardScreen';
import QuizScreen from '@/screens/QuizScreen';

/**
 * M4 — student practice hub. Drill a chapter's flash cards or take its practice
 * quiz. Wired to the seeded chapter-12 content; in production the chapter is
 * chosen from the outline.
 */
type View_ = 'menu' | 'flashcards' | 'quiz';

export default function PracticeScreen() {
  const [view, setView] = useState<View_>('menu');
  const [enrollmentId, setEnrollmentId] = useState<string | null>(null);
  const [chapterId, setChapterId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const enr = await getMyActiveEnrollment();
        setEnrollmentId(enr?.id ?? null);
        // Resolve the chapter id for the demo flashcard chapter number.
        const { data: courses } = await supabase
          .from('courses').select('id').eq('program_id', DEMO.programId);
        const courseIds = (courses ?? []).map((c) => c.id);
        if (courseIds.length > 0) {
          const { data: ch } = await supabase
            .from('chapters').select('id')
            .in('course_id', courseIds)
            .eq('number', DEMO.flashcardChapterNumber)
            .maybeSingle();
          setChapterId(ch?.id ?? null);
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  if (view === 'flashcards' && chapterId) {
    return <Framed title="Flash Cards" onBack={() => setView('menu')}><FlashcardScreen chapterId={chapterId} /></Framed>;
  }
  if (view === 'quiz' && enrollmentId) {
    return <Framed title="Quiz" onBack={() => setView('menu')}><QuizScreen assessmentId={DEMO.chapterQuiz} enrollmentId={enrollmentId} /></Framed>;
  }

  return (
    <View style={s.screen}>
      <Text style={s.h1}>Practice</Text>
      <Text style={s.subtle}>Chapter 10 · Pot Management &amp; Side Pots</Text>
      {error && <Text style={s.error}>{error}</Text>}
      <Pressable style={s.btn} onPress={() => setView('flashcards')} disabled={!chapterId}>
        <Text style={s.btnLabel}>🃏 Flash cards</Text>
        <Text style={s.btnHint}>{chapterId ? 'Drill the deck' : 'No deck available'}</Text>
      </Pressable>
      <Pressable style={s.btn} onPress={() => setView('quiz')} disabled={!enrollmentId}>
        <Text style={s.btnLabel}>📝 Practice quiz</Text>
        <Text style={s.btnHint}>{enrollmentId ? 'Immediate feedback with explanations' : 'No active enrollment'}</Text>
      </Pressable>
    </View>
  );
}

function Framed({ title, onBack, children }: { title: string; onBack: () => void; children: React.ReactNode }) {
  return (
    <View style={{ flex: 1, backgroundColor: theme.color.bg }}>
      <View style={s.bar}>
        <Text style={s.back} onPress={onBack}>‹ Practice</Text>
        <Text style={s.barTitle}>{title}</Text>
        <View style={{ width: 72 }} />
      </View>
      <View style={{ flex: 1 }}>{children}</View>
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg, padding: theme.space(2) },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 24, fontWeight: '800', color: theme.color.felt },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(2) },
  btn: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginBottom: theme.space(1.5) },
  btnLabel: { fontSize: 17, fontWeight: '700', color: theme.color.text },
  btnHint: { color: theme.color.subtle, marginTop: 2 },
  bar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: theme.color.felt, paddingHorizontal: theme.space(1.5), paddingVertical: theme.space(1.5) },
  back: { color: theme.color.brass, fontWeight: '700', width: 72 },
  barTitle: { color: '#fff', fontWeight: '800', fontSize: 16 },
  error: { color: theme.color.danger, marginBottom: theme.space(1) },
});
