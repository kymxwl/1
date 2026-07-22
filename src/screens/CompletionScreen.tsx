import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Linking, Pressable, ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { theme } from '@/theme';
import { evaluateCompletion, distanceToDistinction } from '@/services/completion';
import {
  getCertificate, issueCertificate, signedCertificateUrl, type IssueResult,
} from '@/services/certificates';
import type { Certificate, CompletionEvaluation } from '@/types/database';

/**
 * M8 — Completion & Certificate (admin). Evaluate eligibility, then one button
 * issues a numbered certificate. The outcome is computed; the button is only
 * enabled when the DB says the student is eligible — and the edge function
 * re-checks eligibility regardless.
 */
export default function CompletionScreen({ enrollmentId }: { enrollmentId: string }) {
  const [ev, setEv] = useState<CompletionEvaluation | null>(null);
  const [cert, setCert] = useState<Certificate | null>(null);
  const [loading, setLoading] = useState(true);
  const [issuing, setIssuing] = useState(false);
  const [issued, setIssued] = useState<IssueResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [evaluation, existing] = await Promise.all([
        evaluateCompletion(enrollmentId),
        getCertificate(enrollmentId),
      ]);
      setEv(evaluation);
      setCert(existing);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [enrollmentId]);

  useEffect(() => { void load(); }, [load]);

  async function onIssue() {
    setIssuing(true);
    setError(null);
    try {
      const res = await issueCertificate(enrollmentId);
      setIssued(res);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIssuing(false);
    }
  }

  async function openPdf(pdfUrl: string) {
    try {
      const url = await signedCertificateUrl(pdfUrl);
      await Linking.openURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  if (loading) return <View style={[s.screen, s.center]}><ActivityIndicator color={theme.color.felt} /></View>;

  const eligible = ev?.outcome === 'completed' || ev?.outcome === 'completed_with_distinction';
  const gaps = ev ? distanceToDistinction(ev) : [];

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ padding: theme.space(2) }}>
      <Text style={s.h1}>Completion</Text>

      {error && <Text style={s.error}>{error}</Text>}

      <View style={[s.card, eligible && s.cardOk]}>
        <Text style={s.label}>Computed outcome</Text>
        <Text style={[s.outcome, eligible ? { color: theme.color.felt } : { color: theme.color.subtle }]}>
          {label(ev?.outcome)}
        </Text>
        {ev && (
          <View style={s.metaRow}>
            <Meta label="Clock hrs" value={ev.clock_hours_earned.toFixed(2)} />
            <Meta label="Final" value={ev.final_exam_score != null ? `${ev.final_exam_score}%` : '—'} />
            <Meta label="Attendance" value={`${ev.attendance_pct}%`} />
          </View>
        )}
      </View>

      {!eligible && gaps.length > 0 && (
        <View style={s.card}>
          <Text style={s.label}>Outstanding before eligibility / Distinction</Text>
          {gaps.map((g) => <Text key={g} style={s.gap}>• {g}</Text>)}
        </View>
      )}

      {cert ? (
        <View style={[s.card, s.cardOk]}>
          <Text style={s.label}>Certificate issued</Text>
          <Text style={s.certNo}>{cert.certificate_number}</Text>
          {cert.revoked_at && <Text style={s.error}>Revoked: {cert.revocation_reason}</Text>}
          {cert.pdf_url && (
            <Pressable style={s.linkBtn} onPress={() => openPdf(cert.pdf_url!)}>
              <Text style={s.linkText}>View certificate PDF</Text>
            </Pressable>
          )}
        </View>
      ) : (
        <Pressable
          style={[s.primary, (!eligible || issuing) && { opacity: 0.5 }]}
          disabled={!eligible || issuing}
          onPress={onIssue}
        >
          <Text style={s.primaryText}>
            {issuing ? 'Issuing…' : eligible ? 'Issue certificate' : 'Not eligible'}
          </Text>
        </Pressable>
      )}

      {issued && (
        <Text style={s.issuedNote}>
          Issued {issued.certificate_number} ({issued.outcome.replace(/_/g, ' ')}).
        </Text>
      )}
    </ScrollView>
  );
}

function label(o?: CompletionEvaluation['outcome']): string {
  if (o === 'completed_with_distinction') return 'Completed with Distinction';
  if (o === 'completed') return 'Completed';
  return 'Not yet eligible';
}

function Meta({ label, value }: { label: string; value: string }) {
  return (
    <View style={s.meta}>
      <Text style={s.metaValue}>{value}</Text>
      <Text style={s.subtle}>{label}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg },
  center: { alignItems: 'center', justifyContent: 'center' },
  h1: { fontSize: 24, fontWeight: '800', color: theme.color.felt, marginBottom: theme.space(2) },
  card: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginBottom: theme.space(2) },
  cardOk: { borderColor: theme.color.felt, borderWidth: 2 },
  label: { color: theme.color.subtle, fontWeight: '700' },
  outcome: { fontSize: 22, fontWeight: '900', marginVertical: theme.space(1) },
  metaRow: { flexDirection: 'row', gap: theme.space(2), marginTop: theme.space(1) },
  meta: { flex: 1 },
  metaValue: { fontSize: 20, fontWeight: '800', color: theme.color.text },
  subtle: { color: theme.color.subtle },
  gap: { color: theme.color.text, paddingVertical: 2 },
  primary: { backgroundColor: theme.color.felt, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  primaryText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  certNo: { fontSize: 26, fontWeight: '900', color: theme.color.felt, marginVertical: theme.space(1) },
  linkBtn: { backgroundColor: theme.color.brass, borderRadius: theme.radius, padding: theme.space(1.5), alignItems: 'center', marginTop: theme.space(1) },
  linkText: { color: '#3a2f0a', fontWeight: '800' },
  issuedNote: { color: theme.color.felt, fontWeight: '600', textAlign: 'center' },
  error: { color: theme.color.danger, marginBottom: theme.space(1) },
});
