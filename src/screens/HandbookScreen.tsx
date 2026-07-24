import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator, Linking, Pressable, ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import { supabase } from '@/lib/supabase';
import { DEMO } from '@/demo';
import type { Resource } from '@/types/database';

/**
 * Student/staff handbook: the manual's presentational sections (the TGI
 * Standard, codes/oaths, and — for staff — the instructor forms), loaded as
 * program resources. RLS filters by the viewer's role/visibility, so students
 * never see the instructor-only forms. Resources with a `body` render inline;
 * resources with a `url` link out.
 */
export default function HandbookScreen() {
  const [items, setItems] = useState<Resource[]>([]);
  const [openId, setOpenId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    supabase
      .from('resources')
      .select('*')
      .eq('owner_type', 'program')
      .eq('owner_id', DEMO.programId)
      .then(({ data, error: e }) => {
        if (e) setError(e.message);
        else setItems((data ?? []) as Resource[]);
        setLoading(false);
      });
  }, []);

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;
  if (error) return <View style={[s.screen, s.center]}><Text style={s.error}>{error}</Text></View>;

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Handbook</Text>
      {items.length === 0 && <Text style={s.subtle}>No handbook entries.</Text>}
      {items.map((r) => {
        const open = openId === r.id;
        return (
          <View key={r.id} style={s.card}>
            <Pressable onPress={() => setOpenId(open ? null : r.id)} style={s.head}>
              <Text style={s.title}>{r.title}</Text>
              <Text style={s.chev}>{open ? '−' : '+'}</Text>
            </Pressable>
            {open && (
              <View style={s.bodyWrap}>
                {r.body && <Text style={s.body}>{r.body}</Text>}
                {r.url && (
                  <Pressable style={s.link} onPress={() => void Linking.openURL(r.url!)}>
                    <Text style={s.linkText}>Open document ↗</Text>
                  </Pressable>
                )}
              </View>
            )}
          </View>
        );
      })}
    </ScrollView>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 24, fontWeight: '800', color: theme.color.felt, marginBottom: theme.space(1) },
  subtle: { color: theme.color.subtle },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, marginTop: theme.space(1.5), overflow: 'hidden' },
  head: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: theme.space(2) },
  title: { fontWeight: '700', color: theme.color.text, flex: 1 },
  chev: { color: theme.color.brass, fontWeight: '900', fontSize: 20, marginLeft: theme.space(1) },
  bodyWrap: { paddingHorizontal: theme.space(2), paddingBottom: theme.space(2) },
  body: { color: theme.color.text, lineHeight: 21 },
  link: { marginTop: theme.space(1.5), backgroundColor: theme.color.brass, borderRadius: 8, padding: theme.space(1.25), alignItems: 'center' },
  linkText: { color: '#3a2f0a', fontWeight: '800' },
  error: { color: theme.color.danger, padding: theme.space(2) },
});
