import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import Constants from 'expo-constants';
import type { Database } from '@/types/database';

/**
 * Single Supabase client for the app. The anon key is safe to ship: every table
 * is protected by RLS (see supabase/migrations/..._rls.sql). The client can
 * only ever read/write what the signed-in user's role permits, and answer keys
 * live behind a view the client cannot widen.
 */
const extra = (Constants.expoConfig?.extra ?? {}) as {
  supabaseUrl?: string;
  supabaseAnonKey?: string;
};

const supabaseUrl =
  process.env.EXPO_PUBLIC_SUPABASE_URL ?? extra.supabaseUrl ?? '';
const supabaseAnonKey =
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? extra.supabaseAnonKey ?? '';

if (!supabaseUrl || !supabaseAnonKey) {
  // Fail loud in dev; a misconfigured client is worse than an obvious error.
  console.warn(
    '[supabase] Missing EXPO_PUBLIC_SUPABASE_URL / _ANON_KEY. See .env.example.',
  );
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
