import React, { useState } from 'react';
import {
  ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { theme } from '@/theme';
import { signInWithEmail } from '@/services/session';

export default function SignInScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await signInWithEmail(email.trim(), password);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Sign-in failed');
    } finally {
      setBusy(false);
    }
  }

  return (
    <View style={s.screen}>
      <Text style={s.brand}>TGI</Text>
      <Text style={s.sub}>Texas Gaming Institute — Learning Portal</Text>
      <TextInput
        style={s.input} placeholder="Email" autoCapitalize="none" keyboardType="email-address"
        placeholderTextColor={theme.color.subtle} value={email} onChangeText={setEmail}
      />
      <TextInput
        style={s.input} placeholder="Password" secureTextEntry
        placeholderTextColor={theme.color.subtle} value={password} onChangeText={setPassword}
      />
      {error && <Text style={s.error}>{error}</Text>}
      <Pressable style={[s.btn, busy && { opacity: 0.6 }]} disabled={busy} onPress={submit}>
        {busy ? <ActivityIndicator color="#fff" /> : <Text style={s.btnText}>Sign in</Text>}
      </Pressable>
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.felt, padding: theme.space(3), justifyContent: 'center' },
  brand: { color: theme.color.brass, fontSize: 56, fontWeight: '900', textAlign: 'center' },
  sub: { color: '#cfe0d7', textAlign: 'center', marginBottom: theme.space(4) },
  input: {
    backgroundColor: '#fff', borderRadius: theme.radius, padding: theme.space(1.5),
    marginBottom: theme.space(1.5), color: theme.color.text,
  },
  error: { color: '#ffd7d7', marginBottom: theme.space(1) },
  btn: { backgroundColor: theme.color.brass, borderRadius: theme.radius, padding: theme.space(2), alignItems: 'center' },
  btnText: { color: '#3a2f0a', fontWeight: '800', fontSize: 16 },
});
