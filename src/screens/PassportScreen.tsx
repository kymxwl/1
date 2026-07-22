import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { theme, tierColor } from '@/theme';
import { getMyActiveEnrollment } from '@/services/session';
import { getLedger } from '@/services/attendance';
import { getCurrentTiers, getSkills } from '@/services/skills';
import { evaluateCompletion, distanceToDistinction } from '@/services/completion';
import type {
  ClockHourLedgerRow, CompletionEvaluation, Skill, SkillTier,
} from '@/types/database';

/**
 * M7 — Dealer Passport. The student sees exactly what remains: clock hours,
 * skill tiers, and distance to Distinction. Every number here is read from the
 * ledger/RPCs — nothing is recomputed locally.
 */
const PROGRAM_TOTAL_HOURS = 100;

export default function PassportScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ledger, setLedger] = useState<ClockHourLedgerRow | null>(null);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [tiers, setTiers] = useState<Record<string, SkillTier>>({});
  const [evaluation, setEvaluation] = useState<CompletionEvaluation | null>(null);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      const enr = await getMyActiveEnrollment();
      if (!enr) {
        setError('No active enrollment found.');
        return;
      }
      const [led, ev] = await Promise.all([
        getLedger(enr.id),
        evaluateCompletion(enr.id),
      ]);
      setLedger(led);
      setEvaluation(ev);
      const snap = (ev.criteria_snapshot ?? {}) as { program_id?: string };
      if (snap.program_id) {
        const [sk, tr] = await Promise.all([
          getSkills(snap.program_id),
          getCurrentTiers(enr.id),
        ]);
        setSkills(sk);
        setTiers(tr);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  if (loading) return <Centered><ActivityIndicator color={theme.color.felt} /></Centered>;
  if (error) return <Centered><Text style={s.error}>{error}</Text></Centered>;

  const hours = ledger?.clock_hours_earned ?? 0;
  const pct = Math.min(100, Math.round((hours / PROGRAM_TOTAL_HOURS) * 100));
  const gaps = evaluation ? distanceToDistinction(evaluation) : [];

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Dealer Passport</Text>

      <View style={s.card}>
        <Text style={s.cardLabel}>Clock hours</Text>
        <Text style={s.big}>
          {hours.toFixed(2)} <Text style={s.subtle}>/ {PROGRAM_TOTAL_HOURS}</Text>
        </Text>
        <View style={s.barTrack}>
          <View style={[s.barFill, { width: `${pct}%` }]} />
        </View>
        <Text style={s.subtle}>{pct}% of required hours</Text>
        <View style={s.row}>
          <Stat label="Absences" value={ledger?.absences ?? 0} />
          <Stat label="Tardies" value={ledger?.tardies ?? 0} />
          <Stat label="Excused" value={ledger?.excused_absences ?? 0} />
        </View>
      </View>

      <Text style={s.h2}>Skills</Text>
      <View style={s.card}>
        {skills.length === 0 && <Text style={s.subtle}>No skills recorded yet.</Text>}
        {skills.map((sk) => {
          const tier = tiers[sk.id] ?? null;
          return (
            <View key={sk.id} style={s.skillRow}>
              <Text style={s.skillName}>{sk.name}</Text>
              <View style={[s.tierPill, { backgroundColor: tierColor(tier) }]}>
                <Text style={s.tierText}>{tier ? tier.toUpperCase() : 'NOT YET'}</Text>
              </View>
            </View>
          );
        })}
      </View>

      <Text style={s.h2}>Distance to Distinction</Text>
      <View style={s.card}>
        {evaluation?.outcome === 'completed_with_distinction' ? (
          <Text style={s.distinction}>🏅 Distinction achieved</Text>
        ) : gaps.length === 0 ? (
          <Text style={s.subtle}>Evaluation pending.</Text>
        ) : (
          gaps.map((g) => (
            <Text key={g} style={s.gap}>• {g}</Text>
          ))
        )}
        {evaluation && (
          <Text style={[s.subtle, { marginTop: theme.space(1) }]}>
            Current outcome: {labelOutcome(evaluation.outcome)}
          </Text>
        )}
      </View>
    </ScrollView>
  );
}

function labelOutcome(o: CompletionEvaluation['outcome']): string {
  if (o === 'completed_with_distinction') return 'Completed with Distinction';
  if (o === 'completed') return 'Completed';
  return 'Not yet eligible';
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <View style={s.stat}>
      <Text style={s.statValue}>{value}</Text>
      <Text style={s.subtle}>{label}</Text>
    </View>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return <View style={[s.screen, s.center]}>{children}</View>;
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 26, fontWeight: '800', color: theme.color.felt, marginBottom: theme.space(2) },
  h2: { fontSize: 18, fontWeight: '700', color: theme.color.text, marginTop: theme.space(3), marginBottom: theme.space(1) },
  card: {
    backgroundColor: theme.color.card, borderRadius: theme.radius,
    padding: theme.space(2), borderWidth: 1, borderColor: theme.color.border,
  },
  cardLabel: { color: theme.color.subtle, fontWeight: '600' },
  big: { fontSize: 40, fontWeight: '800', color: theme.color.felt, marginVertical: theme.space(1) },
  subtle: { color: theme.color.subtle },
  barTrack: { height: 10, backgroundColor: theme.color.border, borderRadius: 5, overflow: 'hidden', marginVertical: theme.space(1) },
  barFill: { height: 10, backgroundColor: theme.color.brass },
  row: { flexDirection: 'row', marginTop: theme.space(2), gap: theme.space(2) },
  stat: { flex: 1, alignItems: 'center' },
  statValue: { fontSize: 22, fontWeight: '800', color: theme.color.text },
  skillRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: theme.space(1) },
  skillName: { flex: 1, color: theme.color.text, fontWeight: '600' },
  tierPill: { paddingHorizontal: theme.space(1.5), paddingVertical: 4, borderRadius: 999 },
  tierText: { color: '#fff', fontWeight: '800', fontSize: 12 },
  distinction: { fontSize: 18, fontWeight: '800', color: theme.color.brass },
  gap: { color: theme.color.text, paddingVertical: 2 },
  error: { color: theme.color.danger, padding: theme.space(2) },
});
