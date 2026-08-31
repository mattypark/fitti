import 'server-only';

import { config } from '@/lib/config';

export type Verdict = 'clean' | 'blocked' | 'skipped';

/**
 * Runs before an image becomes retrievable.
 *
 * omni-moderation-latest handles images and is free for API users, so there is no
 * cost argument for skipping it. With no key set it returns 'skipped', which is
 * acceptable for a private closet and NOT acceptable the day anything becomes
 * shareable.
 *
 * A blocked image is quarantined rather than deleted — the audit trail is the
 * point. CSAM is never self-classified here; that is hash-matching against known
 * -hash programmes plus a mandated reporting channel, and it is routed, not
 * guessed at.
 */
export async function moderate(image: Buffer, mime: string): Promise<Verdict> {
  if (!config.hasModeration) return 'skipped';

  try {
    const response = await fetch('https://api.openai.com/v1/moderations', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'omni-moderation-latest',
        input: [
          {
            type: 'image_url',
            image_url: { url: `data:${mime};base64,${image.toString('base64')}` },
          },
        ],
      }),
    });

    if (!response.ok) return 'skipped';

    const body = (await response.json()) as {
      results?: Array<{ flagged: boolean; categories: Record<string, boolean> }>;
    };
    const result = body.results?.[0];
    if (!result) return 'skipped';

    // Only the categories that must hard-block. A photo of a jumper should never
    // trip this, and over-blocking a user's own wardrobe is its own failure.
    const blocking = ['sexual/minors', 'violence/graphic'];
    if (blocking.some((category) => result.categories[category])) return 'blocked';

    return 'clean';
  } catch {
    // A moderation outage must not become an upload outage.
    return 'skipped';
  }
}
