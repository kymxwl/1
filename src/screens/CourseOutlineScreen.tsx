import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator, Linking, Pressable, SectionList, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import { getCourseOutline, type ChapterWithLessons } from '@/services/curriculum';

/**
 * M1 — Curriculum & Content. Student read-only outline: all 25 chapters, their
 * lessons, and linked resources (decks / flash cards). RLS already limits
 * resources to visibility='student' for a student caller.
 */
export default function CourseOutlineScreen({ programId }: { programId: string }) {
  const [chapters, setChapters] = useState<ChapterWithLessons[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getCourseOutline(programId)
      .then(setChapters)
      .catch((e) => setError(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [programId]);

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;
  if (error) return <View style={[s.screen, s.center]}><Text style={s.err}>{error}</Text></View>;

  const sections = chapters.map((ch) => ({
    title: `${ch.number}. ${ch.title}`,
    hours: ch.clock_hours,
    manual: ch.manual_page_ref,
    data: ch.lessons.length > 0 ? ch.lessons : [{ id: `${ch.id}-empty`, title: '(no lessons yet)' } as { id: string; title: string }],
    resources: ch.resources,
  }));

  return (
    <SectionList
      style={s.screen}
      contentContainerStyle={{ padding: theme.space(1.5) }}
      sections={sections}
      keyExtractor={(item) => item.id}
      renderSectionHeader={({ section }) => (
        <View style={s.header}>
          <Text style={s.headerTitle}>{section.title}</Text>
          <Text style={s.headerMeta}>
            {section.hours} hrs{section.manual ? ` · ${section.manual}` : ''}
          </Text>
          {section.resources.length > 0 && (
            <View style={s.resourceRow}>
              {section.resources.map((r) => (
                <Pressable key={r.id} style={s.chip} onPress={() => void Linking.openURL(r.url)}>
                  <Text style={s.chipText}>{r.kind === 'flashcards' ? '🃏' : '📄'} {r.title}</Text>
                </Pressable>
              ))}
            </View>
          )}
        </View>
      )}
      renderItem={({ item }) => (
        <View style={s.lesson}>
          <Text style={s.lessonText}>{item.title}</Text>
        </View>
      )}
      stickySectionHeadersEnabled={false}
    />
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  err: { color: theme.color.danger, padding: theme.space(2) },
  header: {
    backgroundColor: theme.color.felt, borderRadius: theme.radius,
    padding: theme.space(1.5), marginTop: theme.space(1.5),
  },
  headerTitle: { color: '#fff', fontWeight: '800', fontSize: 15 },
  headerMeta: { color: '#cfe0d7', marginTop: 2, fontSize: 12 },
  resourceRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: theme.space(1) },
  chip: { backgroundColor: theme.color.brass, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 4 },
  chipText: { color: '#3a2f0a', fontWeight: '700', fontSize: 12 },
  lesson: {
    backgroundColor: theme.color.card, borderLeftWidth: 3, borderLeftColor: theme.color.brass,
    padding: theme.space(1.5), marginTop: 4, borderRadius: 6,
  },
  lessonText: { color: theme.color.text },
});
