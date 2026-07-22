import React, { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { getRole } from '@/services/session';
import { theme } from '@/theme';
import type { AppRole } from '@/types/database';
import SignInScreen from '@/screens/SignInScreen';
import PassportScreen from '@/screens/PassportScreen';
import CourseOutlineScreen from '@/screens/CourseOutlineScreen';
import StaffConsoleScreen from '@/screens/StaffConsoleScreen';
import { DEMO } from '@/demo';

const Tab = createBottomTabNavigator();

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<AppRole | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (session) void getRole().then(setRole);
    else setRole(null);
  }, [session]);

  if (!ready) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.felt }}>
        <ActivityIndicator color={theme.color.brass} />
      </View>
    );
  }

  if (!session) {
    return (
      <>
        <StatusBar style="light" />
        <SignInScreen />
      </>
    );
  }

  return (
    <NavigationContainer>
      <StatusBar style="dark" />
      <Tab.Navigator
        screenOptions={{
          headerStyle: { backgroundColor: theme.color.felt },
          headerTintColor: '#fff',
          tabBarActiveTintColor: theme.color.felt,
        }}
      >
        <Tab.Screen name="Passport" options={{ title: 'Dealer Passport' }}>
          {() => <PassportScreen />}
        </Tab.Screen>
        <Tab.Screen name="Curriculum" options={{ title: 'Course Outline' }}>
          {() => <CourseOutlineScreen programId={DEMO.programId} />}
        </Tab.Screen>
        {role && role !== 'student' && (
          <Tab.Screen name="Staff" options={{ title: 'Staff Console' }}>
            {() => (
              <StaffConsoleScreen
                profileId={session.user.id}
                displayName={session.user.email ?? 'Staff'}
                role={role}
              />
            )}
          </Tab.Screen>
        )}
      </Tab.Navigator>
    </NavigationContainer>
  );
}
