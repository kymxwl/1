import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator, ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import {
  attendanceRegister, gradeRoster, cohortSummary,
  type AttendanceRegisterRow, type GradeRosterRow, type CohortSummary,
} from '@/services/reporting';

/**
 * M9 — Admin Reporting. Attendance register, grade roster, and cohort summary,
 * all read from the ledger/views. Nothing here is hand-assembled.
 */
type Tab = 'summary' | 'register' | 'roster';

export default function ReportingScreen({ cohortId }: { cohortId: string }) {
  const [tab, setTab] = useState<Tab>('summary');
  const [summary, setSummary] = useState<CohortSummary | null>(null);
  const [register, setRegister] = useState<AttendanceRegisterRow[]>([]);
  const [roster, setRoster] = useState<GradeRosterRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    Promise.all([
      cohortSummary(cohortId),
      attendanceRegister(cohortId),
      gradeRoster(cohortId),
    ])
      .then(([su, reg, ros]) => { setSummary(su); setRegister(reg); setRoster(ros); })
      .catch((e) => setError(e instanceof Error ? e.message : String(e)))
      .finally(() => setLoading(false));
  }, [cohortId]);

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;
  if (error) return <View style={[s.screen, s.center]}><Text style={s.error}>{error}</Text></View>;

  return (
    <View style={s.screen}>
      <View style={s.tabs}>
        {(['summary', 'register', 'roster'] as Tab[]).map((t) => (
          <Text
            key={t}
            onPress={() => setTab(t)}
            style={[s.tab, tab === t && s.tabActive]}
          >
            {t === 'summary' ? 'Summary' : t === 'register' ? 'Attendance' : 'Grades'}
          </Text>
        ))}
      </View>

      <ScrollView contentContainerStyle={{ padding: theme.space(2) }}>
        {tab === 'summary' && summary && (
          <View style={s.cardGrid}>
            <Metric label="Enrolled" value={String(summary.enrolled)} />
            <Metric label="Avg clock hrs" value={summary.avgClockHours.toFixed(2)} />
            <Metric label="Total clock hrs" value={summary.totalClockHours.toFixed(2)} />
            <Metric label="Perfect attendance" value={String(summary.perfectAttendance)} />
          </View>
        )}

        {tab === 'register' && (
          <View style={s.table}>
            <Row header cells={['Student', 'Hrs', 'Abs', 'Tdy', 'Exc']} />
            {register.map((r) => (
              <Row
                key={r.enrollmentId}
                cells={[r.studentName, r.clockHours.toFixed(2), String(r.absences), String(r.tardies), String(r.excused)]}
              />
            ))}
          </View>
        )}

        {tab === 'roster' && (
          <View style={s.table}>
            <Row header cells={['Student', 'Final', 'Pass', 'Gold']} />
            {roster.map((r) => (
              <Row
                key={r.enrollmentId}
                cells={[
                  r.studentName,
                  r.bestFinalScore != null ? `${r.bestFinalScore}%` : '—',
                  r.finalPassed ? '✓' : '—',
                  `${r.goldSkills}/${r.totalSkills}`,
                ]}
              />
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <View style={s.metric}>
      <Text style={s.metricValue}>{value}</Text>
      <Text style={s.metricLabel}>{label}</Text>
    </View>
  );
}

function Row({ cells, header }: { cells: string[]; header?: boolean }) {
  return (
    <View style={[s.row, header && s.rowHeader]}>
      {cells.map((c, i) => (
        <Text
          key={i}
          style={[s.cell, i === 0 && s.cellFirst, header && s.cellHeader]}
          numberOfLines={1}
        >
          {c}
        </Text>
      ))}
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  tabs: { flexDirection: 'row', backgroundColor: theme.color.felt },
  tab: { flex: 1, textAlign: 'center', paddingVertical: theme.space(1.5), color: '#cfe0d7', fontWeight: '700' },
  tabActive: { color: '#fff', backgroundColor: theme.color.feltLight },
  cardGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: theme.space(1.5) },
  metric: { width: '47%', backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2) },
  metricValue: { fontSize: 28, fontWeight: '900', color: theme.color.felt },
  metricLabel: { color: theme.color.subtle, marginTop: 4 },
  table: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, overflow: 'hidden' },
  row: { flexDirection: 'row', paddingVertical: theme.space(1.25), paddingHorizontal: theme.space(1.5), borderBottomWidth: 1, borderBottomColor: theme.color.border },
  rowHeader: { backgroundColor: '#eef1ee' },
  cell: { width: 52, textAlign: 'right', color: theme.color.text },
  cellFirst: { flex: 1, textAlign: 'left', fontWeight: '600' },
  cellHeader: { color: theme.color.subtle, fontWeight: '800', fontSize: 12 },
  error: { color: theme.color.danger, padding: theme.space(2) },
});
