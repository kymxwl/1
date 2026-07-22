import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View,
} from 'react-native';
import { theme, tierColor } from '@/theme';
import { getSkills, getBenchmarks, recordEvaluation } from '@/services/skills';
import type { Skill, SkillBenchmark } from '@/types/database';

/**
 * M6 — Skill Evaluation (rubric capture). The instructor records the metric or
 * ticks the checklist; the awarded tier comes back from the DB (compute_skill_tier
 * trigger). No control here lets the instructor choose a tier.
 */
interface Props {
  programId: string;
  enrollmentId: string;
  evaluatorId: string;
  sessionId?: string;
}

export default function SkillEvaluationScreen({
  programId, enrollmentId, evaluatorId, sessionId,
}: Props) {
  const [skills, setSkills] = useState<Skill[]>([]);
  const [skillId, setSkillId] = useState<string | null>(null);
  const [benchmarks, setBenchmarks] = useState<SkillBenchmark[]>([]);
  const [rawMetric, setRawMetric] = useState('');
  const [checklist, setChecklist] = useState<Record<string, boolean>>({});
  const [awarded, setAwarded] = useState<string | null | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getSkills(programId).then((sk) => {
      setSkills(sk);
      setSkillId((prev) => prev ?? sk[0]?.id ?? null);
    }).catch((e) => setError(String(e))).finally(() => setLoading(false));
  }, [programId]);

  const loadBenchmarks = useCallback(async (id: string) => {
    const b = await getBenchmarks(id);
    setBenchmarks(b);
    setRawMetric('');
    setChecklist({});
    setAwarded(undefined);
  }, []);

  useEffect(() => {
    if (skillId) void loadBenchmarks(skillId);
  }, [skillId, loadBenchmarks]);

  const metricType = benchmarks[0]?.metric_type ?? 'time';
  const checklistItems = useMemo(() => {
    const set = new Set<string>();
    for (const b of benchmarks) {
      const req = (b.criteria as { required?: string[] } | null)?.required ?? [];
      for (const k of req) set.add(k);
    }
    return [...set];
  }, [benchmarks]);

  async function submit() {
    if (!skillId) return;
    setSaving(true);
    setError(null);
    try {
      const row = await recordEvaluation({
        enrollmentId,
        skillId,
        evaluatorId,
        rawMetric: metricType === 'checklist' ? undefined : Number(rawMetric),
        checklistResults: metricType === 'checklist' ? checklist : undefined,
        sessionId,
        notes: undefined,
      });
      setAwarded(row.tier_awarded); // computed by the DB
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Score a Skill</Text>

      <Text style={s.label}>Skill</Text>
      <View style={s.skillPicker}>
        {skills.map((sk) => (
          <Pressable
            key={sk.id}
            style={[s.skillChip, skillId === sk.id && s.skillChipActive]}
            onPress={() => setSkillId(sk.id)}
          >
            <Text style={[s.skillChipText, skillId === sk.id && s.skillChipTextActive]}>{sk.name}</Text>
          </Pressable>
        ))}
      </View>

      <View style={s.card}>
        <Text style={s.label}>Benchmarks</Text>
        {benchmarks
          .slice()
          .sort((a, b) => rank(b.tier) - rank(a.tier))
          .map((b) => (
            <View key={b.id} style={s.benchRow}>
              <View style={[s.tierPill, { backgroundColor: tierColor(b.tier) }]}>
                <Text style={s.tierText}>{b.tier.toUpperCase()}</Text>
              </View>
              <Text style={s.benchText}>{b.description}</Text>
            </View>
          ))}
      </View>

      <View style={s.card}>
        <Text style={s.label}>Record what happened</Text>
        {metricType === 'checklist' ? (
          checklistItems.map((item) => (
            <View key={item} style={s.checkRow}>
              <Text style={s.checkText}>{humanize(item)}</Text>
              <Switch
                value={!!checklist[item]}
                onValueChange={(v) => setChecklist((p) => ({ ...p, [item]: v }))}
                trackColor={{ true: theme.color.felt, false: theme.color.border }}
              />
            </View>
          ))
        ) : (
          <View>
            <Text style={s.subtle}>
              {metricType === 'time' ? 'Time in seconds (lower is better)'
                : metricType === 'accuracy' ? 'Accuracy % (higher is better)'
                : 'Count (higher is better)'}
            </Text>
            <TextInput
              style={s.metricInput}
              keyboardType="decimal-pad"
              value={rawMetric}
              onChangeText={setRawMetric}
              placeholder="0"
              placeholderTextColor={theme.color.subtle}
            />
          </View>
        )}
      </View>

      {error && <Text style={s.error}>{error}</Text>}

      <Pressable
        style={[s.submit, saving && { opacity: 0.6 }]}
        disabled={saving || (metricType !== 'checklist' && rawMetric.trim() === '')}
        onPress={submit}
      >
        <Text style={s.submitText}>{saving ? 'Recording…' : 'Record evaluation'}</Text>
      </Pressable>

      {awarded !== undefined && (
        <View style={[s.result, { borderColor: tierColor(awarded as never) }]}>
          <Text style={s.resultLabel}>System-assigned tier</Text>
          <Text style={[s.resultTier, { color: tierColor(awarded as never) }]}>
            {awarded ? awarded.toUpperCase() : 'NO TIER REACHED'}
          </Text>
          <Text style={s.subtle}>Computed from the recorded metric — not chosen.</Text>
        </View>
      )}
    </ScrollView>
  );
}

function rank(t: string): number {
  return t === 'gold' ? 3 : t === 'silver' ? 2 : 1;
}
function humanize(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 24, fontWeight: '800', color: theme.color.felt, marginBottom: theme.space(2) },
  label: { fontWeight: '700', color: theme.color.text, marginBottom: theme.space(1) },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(1) },
  skillPicker: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: theme.space(2) },
  skillChip: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 8, backgroundColor: theme.color.card },
  skillChipActive: { backgroundColor: theme.color.felt, borderColor: theme.color.felt },
  skillChipText: { color: theme.color.text, fontWeight: '600' },
  skillChipTextActive: { color: '#fff' },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, padding: theme.space(2), borderWidth: 1, borderColor: theme.color.border, marginBottom: theme.space(2) },
  benchRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(1), paddingVertical: 4 },
  benchText: { flex: 1, color: theme.color.text },
  tierPill: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 999, minWidth: 64, alignItems: 'center' },
  tierText: { color: '#fff', fontWeight: '800', fontSize: 11 },
  checkRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: theme.space(1) },
  checkText: { color: theme.color.text, flex: 1 },
  metricInput: { borderWidth: 1, borderColor: theme.color.border, borderRadius: 8, padding: theme.space(1.5), fontSize: 20, color: theme.color.text, marginTop: 4 },
  submit: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  submitText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  error: { color: theme.color.danger, marginBottom: theme.space(1) },
  result: { marginTop: theme.space(2), backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 2, padding: theme.space(2), alignItems: 'center' },
  resultLabel: { color: theme.color.subtle, fontWeight: '600' },
  resultTier: { fontSize: 28, fontWeight: '900', marginVertical: 4 },
});
