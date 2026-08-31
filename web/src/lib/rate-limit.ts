import 'server-only';

import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';
import { config } from '@/lib/config';

/**
 * No Upstash credentials means every limiter passes, which is what a laptop
 * wants. Set them before a single real person uses this: upload and inference are
 * the two routes where somebody else can spend your money.
 */
const redis = config.hasRateLimit ? Redis.fromEnv() : null;

function limiter(tokens: number, window: `${number} ${'s' | 'm' | 'h'}`, prefix: string) {
  if (!redis) return null;
  return new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(tokens, window),
    prefix,
    analytics: true,
  });
}

export const uploadLimit = limiter(30, '1 h', 'rl:upload');
export const inferenceLimit = limiter(10, '1 m', 'rl:ai');
export const authLimit = limiter(5, '15 m', 'rl:auth');

/**
 * Keyed on user id, never IP. One shared network should not throttle everyone
 * behind it, and an authenticated user is the thing whose cost we actually cap.
 */
export async function checkLimit(
  rl: Ratelimit | null,
  userId: string,
): Promise<{ ok: true } | { ok: false; retryAfter: number }> {
  if (!rl) return { ok: true };
  const { success, reset } = await rl.limit(userId);
  if (success) return { ok: true };
  return { ok: false, retryAfter: Math.max(1, Math.ceil((reset - Date.now()) / 1000)) };
}
