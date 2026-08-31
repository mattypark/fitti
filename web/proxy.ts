import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { config as appConfig } from '@/lib/config';

/**
 * Next 16's rename of middleware.ts. Refreshes the auth session on every request.
 *
 * Two rules that look like style and are not:
 *
 * 1. Return the `supabaseResponse` object unmodified. Copying its cookies onto a
 *    fresh NextResponse desynchronises browser and server and logs users out at
 *    random intervals.
 * 2. Put no code between createServerClient and getClaims. Anything in between
 *    can read a stale session.
 *
 * This is UX, not the security boundary — it redirects; it does not authorise.
 * Every route handler independently verifies the user.
 */
export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(appConfig.supabaseUrl, appConfig.supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options),
        );
      },
    },
  });

  await supabase.auth.getClaims();

  return supabaseResponse;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|webp)$).*)'],
};
