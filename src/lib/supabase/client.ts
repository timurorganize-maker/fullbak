import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Browser Supabase client. Returns null when env vars are not configured
 * so the app can run on mock data (prototype mode) without a backend.
 * Wire real data by setting NEXT_PUBLIC_SUPABASE_URL / _ANON_KEY.
 */
let cached: SupabaseClient | null | undefined;

export function getSupabaseBrowser(): SupabaseClient | null {
  if (cached !== undefined) return cached;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    cached = null;
    return null;
  }
  cached = createClient(url, key, {
    auth: { persistSession: true, autoRefreshToken: true },
    realtime: { params: { eventsPerSecond: 5 } },
  });
  return cached;
}

export const isBackendConfigured = Boolean(
  process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
);
