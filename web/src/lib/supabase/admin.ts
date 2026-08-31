import 'server-only';

import { createClient } from '@supabase/supabase-js';
import { config } from '@/lib/config';

/**
 * Service-role client. BYPASSES EVERY RLS POLICY.
 *
 * Any route using this must do its own ownership check first, because the
 * database will no longer do it. Reach for the request-scoped client in
 * ./server.ts unless you specifically need to act as the system.
 */
export function createAdminClient() {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
