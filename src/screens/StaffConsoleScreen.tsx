import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { theme } from '@/theme';
import { DEMO } from '@/demo';
import TakeAttendanceScreen from '@/screens/TakeAttendanceScreen';
import SkillEvaluationScreen from '@/screens/SkillEvaluationScreen';
import SecureExamScreen from '@/screens/SecureExamScreen';
import ReportingScreen from '@/screens/ReportingScreen';
import CompletionScreen from '@/screens/CompletionScreen';
import CohortAdminScreen from '@/screens/CohortAdminScreen';
import PracticalExamScreen from '@/screens/PracticalExamScreen';
import WrittenGradingScreen from '@/screens/WrittenGradingScreen';

/**
 * Instructor / admin hub. Switches between the M3/M5/M6/M9 consoles, wired to
 * the seeded demo cohort. In production the target cohort/session/student comes
 * from live pickers rather than DEMO constants.
 */
type View_ = 'menu' | 'attendance' | 'skill' | 'exam' | 'practical' | 'grading' | 'reporting' | 'completion' | 'cohorts';

interface Props {
  profileId: string;
  displayName: string;
  role: 'instructor' | 'admin';
}

export default function StaffConsoleScreen({ profileId, displayName, role }: Props) {
  const [view, setView] = useState<View_>('menu');

  if (view === 'attendance') {
    return (
      <Framed title="Take Attendance" onBack={() => setView('menu')}>
        <TakeAttendanceScreen
          sessionId={DEMO.sessionId}
          cohortId={DEMO.cohortId}
          instructorProfileId={profileId}
          defaultMinutes={DEMO.scheduledMinutes}
        />
      </Framed>
    );
  }
  if (view === 'skill') {
    return (
      <Framed title="Score a Skill" onBack={() => setView('menu')}>
        <SkillEvaluationScreen
          programId={DEMO.programId}
          enrollmentId={DEMO.enrollmentId}
          evaluatorId={profileId}
          sessionId={DEMO.sessionId}
        />
      </Framed>
    );
  }
  if (view === 'exam') {
    return (
      <Framed title="Proctor Exam" onBack={() => setView('menu')}>
        <SecureExamScreen
          assessmentId={DEMO.finalFormA}
          enrollmentId={DEMO.enrollmentId}
          proctorId={profileId}
          proctorName={displayName}
        />
      </Framed>
    );
  }
  if (view === 'practical') {
    return (
      <Framed title="Practical Exam" onBack={() => setView('menu')}>
        <PracticalExamScreen
          programId={DEMO.programId}
          enrollmentId={DEMO.enrollmentId}
          assessmentId={DEMO.finalPractical}
          proctorId={profileId}
        />
      </Framed>
    );
  }
  if (view === 'grading') {
    return (
      <Framed title="Grade Written Exams" onBack={() => setView('menu')}>
        <WrittenGradingScreen />
      </Framed>
    );
  }
  if (view === 'reporting') {
    return (
      <Framed title="Reporting" onBack={() => setView('menu')}>
        <ReportingScreen cohortId={DEMO.cohortId} />
      </Framed>
    );
  }
  if (view === 'completion') {
    return (
      <Framed title="Completion" onBack={() => setView('menu')}>
        <CompletionScreen enrollmentId={DEMO.enrollmentId} />
      </Framed>
    );
  }
  if (view === 'cohorts') {
    return (
      <Framed title="Cohorts" onBack={() => setView('menu')}>
        <CohortAdminScreen programId={DEMO.programId} />
      </Framed>
    );
  }

  return (
    <View style={s.screen}>
      <Text style={s.h1}>Staff Console</Text>
      <Text style={s.subtle}>Signed in as {displayName} · {role}</Text>
      <MenuButton label="Take attendance" hint="M3 · offline-tolerant" onPress={() => setView('attendance')} />
      <MenuButton label="Score a skill" hint="M6 · tier computed by the system" onPress={() => setView('skill')} />
      <MenuButton label="Proctor a secure exam" hint="M5 · server-side grading" onPress={() => setView('exam')} />
      <MenuButton label="Final practical exam" hint="Ch 25 · 9 categories, computed composite" onPress={() => setView('practical')} />
      <MenuButton label="Grade written exams" hint="Appendix L · mark essays, computed score" onPress={() => setView('grading')} />
      {role === 'admin' && (
        <>
          <MenuButton label="Cohorts & scheduling" hint="M2 · create cohort, generate calendar, enrol" onPress={() => setView('cohorts')} />
          <MenuButton label="Reporting" hint="M9 · registers & rosters from the ledger" onPress={() => setView('reporting')} />
          <MenuButton label="Completion & certificate" hint="M8 · one-button issue, gapless number" onPress={() => setView('completion')} />
        </>
      )}
    </View>
  );
}

function MenuButton({ label, hint, onPress }: { label: string; hint: string; onPress: () => void }) {
  return (
    <Pressable style={s.menuBtn} onPress={onPress}>
      <Text style={s.menuLabel}>{label}</Text>
      <Text style={s.menuHint}>{hint}</Text>
    </Pressable>
  );
}

function Framed({ title, onBack, children }: { title: string; onBack: () => void; children: React.ReactNode }) {
  return (
    <View style={{ flex: 1, backgroundColor: theme.color.bg }}>
      <View style={s.bar}>
        <Text style={s.back} onPress={onBack}>‹ Console</Text>
        <Text style={s.barTitle}>{title}</Text>
        <View style={{ width: 64 }} />
      </View>
      <View style={{ flex: 1 }}>{children}</View>
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.bg, padding: theme.space(2) },
  h1: { fontSize: 24, fontWeight: '800', color: theme.color.felt },
  subtle: { color: theme.color.subtle, marginBottom: theme.space(2) },
  menuBtn: { backgroundColor: theme.color.card, borderRadius: theme.radius, borderWidth: 1, borderColor: theme.color.border, padding: theme.space(2), marginBottom: theme.space(1.5) },
  menuLabel: { fontSize: 16, fontWeight: '700', color: theme.color.text },
  menuHint: { color: theme.color.subtle, marginTop: 2 },
  bar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', backgroundColor: theme.color.felt, paddingHorizontal: theme.space(1.5), paddingVertical: theme.space(1.5) },
  back: { color: theme.color.brass, fontWeight: '700', width: 64 },
  barTitle: { color: '#fff', fontWeight: '800', fontSize: 16 },
});
