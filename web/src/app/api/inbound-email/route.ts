import { NextResponse, type NextRequest } from 'next/server';
import { createHmac, timingSafeEqual, randomUUID } from 'node:crypto';

import { createAdminClient } from '@/lib/supabase/admin';
import { parseReceipt, isSafeImageUrl, type ReceiptItem } from '@/lib/ingest/receipt';
import { derive } from '@/lib/ingest/image';
import { storage, objectKey } from '@/lib/storage';

export const runtime = 'nodejs';

/** Product photos are small; anything larger is not a product photo. */
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_ITEMS_PER_EMAIL = 40;

/**
 * Receives a forwarded order confirmation and turns it into garments.
 *
 * This endpoint is reachable by anyone who learns the URL, and its input is a
 * whole email written by a third party. So: the signature is checked before the
 * body is looked at, the recipient address is the only thing that decides whose
 * closet is written to, and every image URL is validated before it is fetched.
 */
export async function POST(request: NextRequest) {
  const secret = process.env.INBOUND_EMAIL_SECRET;
  const signature = request.headers.get('x-fitti-signature');
  const raw = await request.text();

  if (!secret) {
    // Refuse rather than accept unsigned mail. An open endpoint that writes to
    // user accounts is worse than a missing feature.
    return NextResponse.json({ error: 'Inbound email is not configured.' }, { status: 503 });
  }
  if (!verify(raw, signature, secret)) {
    return NextResponse.json({ error: 'Bad signature' }, { status: 401 });
  }

  let payload: { to?: string; from?: string; subject?: string; html?: string };
  try {
    payload = JSON.parse(raw);
  } catch {
    return NextResponse.json({ error: 'Bad payload' }, { status: 400 });
  }

  const slug = slugFromAddress(payload.to);
  if (!slug) return NextResponse.json({ error: 'Unknown recipient' }, { status: 404 });

  const admin = createAdminClient();
  const { data: profile } = await admin
    .from('profiles')
    .select('id')
    .eq('inbox_slug', slug)
    .maybeSingle();

  // Same response either way. Telling a stranger which addresses exist turns this
  // into an account-enumeration oracle.
  if (!profile) return NextResponse.json({ received: true }, { status: 202 });

  const receipt = parseReceipt(payload.html ?? '');
  if (!receipt.items.length) {
    return NextResponse.json({ received: true, imported: 0, reason: receipt.method });
  }

  let imported = 0;
  for (const item of receipt.items.slice(0, MAX_ITEMS_PER_EMAIL)) {
    if (await importItem(admin, profile.id, item, receipt.merchant)) imported += 1;
  }

  return NextResponse.json({ received: true, imported });
}

function verify(body: string, signature: string | null, secret: string): boolean {
  if (!signature) return false;
  const expected = createHmac('sha256', secret).update(body).digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(signature);
  // Length check first: timingSafeEqual throws on a mismatch rather than
  // returning false, and that throw would itself leak length.
  return a.length === b.length && timingSafeEqual(a, b);
}

/** u_<slug>@in.fitti.app -> <slug> */
function slugFromAddress(to: string | undefined): string | null {
  if (!to) return null;
  const match = to.match(/u_([a-z0-9]+)@/i);
  return match ? match[1].toLowerCase() : null;
}

async function importItem(
  admin: ReturnType<typeof createAdminClient>,
  userId: string,
  item: ReceiptItem,
  merchant: string | undefined,
): Promise<boolean> {
  if (!isSafeImageUrl(item.imageUrl)) return false;

  let bytes: Buffer;
  try {
    // A timeout matters here: a slow or hanging host would otherwise hold the
    // request open for every item in the email.
    const response = await fetch(item.imageUrl, {
      signal: AbortSignal.timeout(8000),
      redirect: 'error', // a redirect could land somewhere isSafeImageUrl rejected
    });
    if (!response.ok) return false;

    const length = Number(response.headers.get('content-length') ?? 0);
    if (length > MAX_IMAGE_BYTES) return false;

    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.byteLength > MAX_IMAGE_BYTES) return false;
    bytes = buffer;
  } catch {
    return false;
  }

  let derivatives;
  try {
    derivatives = await derive(bytes);
  } catch {
    return false;
  }

  const garmentId = randomUUID();
  const { error } = await admin.from('garments').insert({
    id: garmentId,
    user_id: userId,
    name: item.name,
    brand: item.brand ?? merchant ?? null,
    source: 'email',
    status: 'processing',
    width: derivatives.width,
    height: derivatives.height,
    attrs: {
      price_cents: item.priceCents,
      currency: item.currency,
      size: item.size,
      product_url: item.productUrl,
    },
  });
  // A full closet is not an error worth retrying; stop importing this one.
  if (error) return false;

  const keys = {
    master: objectKey(userId, garmentId, 'master', 'webp'),
    preview: objectKey(userId, garmentId, 'preview', 'webp'),
    thumb: objectKey(userId, garmentId, 'thumb', 'webp'),
  };

  try {
    await Promise.all([
      storage.put(keys.master, derivatives.master, 'image/webp'),
      storage.put(keys.preview, derivatives.preview, 'image/webp'),
      storage.put(keys.thumb, derivatives.thumb, 'image/webp'),
    ]);
  } catch {
    await admin.from('garments').delete().eq('id', garmentId);
    return false;
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

  return true;
}
