import 'server-only';

/**
 * Configuration, with a working local fallback for everything.
 *
 * Fitti boots with no keys at all. The *presence* of a key is what switches a
 * feature on, rather than a separate flag — a flag can disagree with reality and
 * this cannot.
 */

// The public demo JWTs `supabase start` prints. Not secrets; they are identical
// on every developer's machine and only ever reach a local container.
const LOCAL_SUPABASE_URL = 'http://127.0.0.1:54421';
const LOCAL_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const LOCAL_SERVICE_ROLE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

export const config = {
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL ?? LOCAL_SUPABASE_URL,
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? LOCAL_ANON_KEY,
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? LOCAL_SERVICE_ROLE_KEY,

  r2: {
    accountId: process.env.R2_ACCOUNT_ID,
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    bucket: process.env.R2_BUCKET ?? 'fitti',
  },

  /** Absent keys mean the pipeline still runs — it just skips that step. */
  get hasR2() {
    return Boolean(process.env.R2_ACCOUNT_ID && process.env.R2_ACCESS_KEY_ID);
  },
  get hasModeration() {
    return Boolean(process.env.OPENAI_API_KEY);
  },
  get hasTagging() {
    return Boolean(process.env.GEMINI_API_KEY);
  },
  get hasRateLimit() {
    return Boolean(process.env.UPSTASH_REDIS_REST_URL);
  },
} as const;
