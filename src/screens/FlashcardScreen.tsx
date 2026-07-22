import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import { getFlashcards } from '@/services/practice';
import type { Flashcard } from '@/types/database';

/**
 * M4 — Flash card drill. Tap a card to flip; step through the deck. Content
 * comes from the `flashcards` table (study material, not exam questions).
 */
export default function FlashcardScreen({ chapterId }: { chapterId: string }) {
  const [cards, setCards] = useState<Flashcard[]>([]);
  const [idx, setIdx] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getFlashcards(chapterId)
      .then(setCards)
      .catch((e) => setError(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [chapterId]);

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;
  if (error) return <View style={[s.screen, s.center]}><Text style={s.error}>{error}</Text></View>;
  if (cards.length === 0) return <View style={[s.screen, s.center]}><Text style={s.subtle}>No flash cards for this chapter yet.</Text></View>;

  const card = cards[idx]!;
  const go = (d: number) => { setIdx((i) => (i + d + cards.length) % cards.length); setFlipped(false); };

  return (
    <View style={s.screen}>
      <Text style={s.counter}>{idx + 1} / {cards.length}</Text>

      <Pressable style={[s.card, flipped && s.cardBack]} onPress={() => setFlipped((f) => !f)}>
        <Text style={s.side}>{flipped ? 'BACK' : 'FRONT'}</Text>
        <Text style={s.cardText}>{flipped ? card.back : card.front}</Text>
        <Text style={s.tapHint}>{flipped ? 'Tap to hide' : 'Tap to reveal'}</Text>
      </Pressable>

      <View style={s.nav}>
        <Pressable style={s.navBtn} onPress={() => go(-1)}><Text style={s.navText}>‹ Prev</Text></Pressable>
        <Pressable style={s.navBtn} onPress={() => go(1)}><Text style={s.navText}>Next ›</Text></Pressable>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg, padding: theme.space(2) },
  center: { alignItems: 'center', justifyContent: 'center' },
  counter: { textAlign: 'center', color: theme.color.subtle, fontWeight: '700', marginBottom: theme.space(1) },
  card: { flex: 1, backgroundColor: theme.color.felt, borderRadius: theme.radius * 1.5, alignItems: 'center', justifyContent: 'center', padding: theme.space(3), marginBottom: theme.space(2) },
  cardBack: { backgroundColor: theme.color.feltLight },
  side: { color: theme.color.brass, fontWeight: '800', letterSpacing: 2, marginBottom: theme.space(2) },
  cardText: { color: '#fff', fontSize: 24, fontWeight: '700', textAlign: 'center' },
  tapHint: { color: '#cfe0d7', marginTop: theme.space(3) },
  nav: { flexDirection: 'row', gap: theme.space(2) },
  navBtn: { flex: 1, backgroundColor: theme.color.card, borderWidth: 1, borderColor: theme.color.border, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  navText: { color: theme.color.felt, fontWeight: '800' },
  subtle: { color: theme.color.subtle },
  error: { color: theme.color.danger },
});
