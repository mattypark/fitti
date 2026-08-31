import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { config } from '@/lib/config';

/**
 * Per-request client. Never a module-level singleton: with Fluid Compute one
 * instance is reused across requests, and a shared client leaks one user's
 * session into another's request.
 *
 * getUser(), not getSession(). getSession reads the cookie and believes it;
 * getUser revalidates the token with Supabase. On a server that difference is the
 * whole point — a cookie is exactly what an attacker controls.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(config.supabaseUrl, config.supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Server Components cannot write cookies. The proxy refreshes the
          // session instead, so this is safe to swallow.
        }
      },
    },
  });
}
