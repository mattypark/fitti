import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';
import { randomUUID } from 'node:crypto';

import { createClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { checkLimit, uploadLimit } from '@/lib/rate-limit';
import { derive, sniff } from '@/lib/ingest/image';
import { moderate } from '@/lib/ingest/moderate';
import { storage, objectKey } from '@/lib/storage';

// sharp is native; the edge runtime cannot load it.
export const runtime = 'nodejs';

const MAX_BYTES = 15 * 1024 * 1024;

const metaSchema = z.object({
  // The CLIENT generates the id before uploading, so a retry is idempotent and
  // the phone can draw a tile with its final identity immediately.
  id: z.uuid(),
  name: z.string().min(1).max(120).optional(),
  source: z.enum(['camera', 'library', 'share_ext', 'email', 'web']).default('web'),
});

/**
 * Ingest one garment.
 *
 * Order matters: authorise, then limit, then validate, then strip, then moderate,
 * and only then does anything become retrievable. Moderation running before the
 * image is reachable is the whole reason it is worth running.
 */
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Not signed in' }, { status: 401 });
  }

  const limit = await checkLimit(uploadLimit, user.id);
  if (!limit.ok) {
    return NextResponse.json(
      { error: 'Too many uploads. Give it a minute.' },
      { status: 429, headers: { 'Retry-After': String(limit.retryAfter) } },
    );
  }

  const form = await request.formData().catch(() => null);
  const file = form?.get('file');

  if (!(file instanceof File) || file.size === 0 || file.size > MAX_BYTES) {
    return NextResponse.json({ error: 'Send one image under 15MB.' }, { status: 400 });
  }

  const parsed = metaSchema.safeParse({
    id: form?.get('id') ?? randomUUID(),
    name: form?.get('name') ?? undefined,
    source: form?.get('source') ?? undefined,
  });
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid request.' }, { status: 400 });
  }

  const input = Buffer.from(await file.arrayBuffer());
  const mime = sniff(input);
  if (!mime) {
    return NextResponse.json({ error: "That file isn't an image." }, { status: 400 });
  }

  let derivatives;
  try {
    derivatives = await derive(input);
  } catch {
    return NextResponse.json({ error: "Couldn't read that image." }, { status: 400 });
  }

  const verdict = await moderate(derivatives.preview, 'image/webp');

  const admin = createAdminClient();
  const garmentId = parsed.data.id;

  // user_id comes from the verified session, never from the request body.
  const { error: insertError } = await admin.from('garments').insert({
    id: garmentId,
    user_id: user.id,
    name: parsed.data.name ?? null,
    source: parsed.data.source,
    status: verdict === 'blocked' ? 'quarantined' : 'processing',
    width: derivatives.width,
    height: derivatives.height,
  });

  if (insertError) {
    // The database trigger enforces the free ceiling, so this is the paywall
    // speaking rather than a failure.
    if (insertError.message.includes('garment_limit_reached')) {
      return NextResponse.json(
        { error: 'Closet full', code: 'limit_reached' },
        { status: 402 },
      );
    }
    return NextResponse.json({ error: "Couldn't save that." }, { status: 500 });
  }

  if (verdict === 'blocked') {
    // Quarantined: the row exists for the audit trail, the bytes never land.
    return NextResponse.json({ error: 'That image was rejected.' }, { status: 422 });
  }

  const keys = {
    master: objectKey(user.id, garmentId, 'master', 'webp'),
    preview: objectKey(user.id, garmentId, 'preview', 'webp'),
    thumb: objectKey(user.id, garmentId, 'thumb', 'webp'),
  };

  try {
    await Promise.all([
      storage.put(keys.master, derivatives.master, 'image/webp'),
      storage.put(keys.preview, derivatives.preview, 'image/webp'),
      storage.put(keys.thumb, derivatives.thumb, 'image/webp'),
    ]);
  } catch {
    await admin.from('garments').delete().eq('id', garmentId);
    return NextResponse.json({ error: "Couldn't store that image." }, { status: 502 });
  }

  await admin
    .from('garments')
    .update({
      master_key: keys.master,
      cutout_key: keys.preview,
      thumb_key: keys.thumb,
      status: 'ready',
    })
    .eq('id', garmentId);

  await admin.from('garment_assets').insert([
    { garment_id: garmentId, user_id: user.id, role: 'master', object_key: keys.master,
      content_type: 'image/webp', bytes: derivatives.master.byteLength,
      width: derivatives.width, height: derivatives.height },
    { garment_id: garmentId, user_id: user.id, role: 'preview', object_key: keys.preview,
      content_type: 'image/webp', bytes: derivatives.preview.byteLength,
      width: derivatives.width, height: derivatives.height },
    { garment_id: garmentId, user_id: user.id, role: 'thumb', object_key: keys.thumb,
      content_type: 'image/webp', bytes: derivatives.thumb.byteLength,
      width: 400, height: 400 },
  ]);

  return NextResponse.json({ id: garmentId, status: 'ready' }, { status: 201 });
}
