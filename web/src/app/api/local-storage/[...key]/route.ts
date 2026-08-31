import { NextResponse } from 'next/server';
import { readFile } from 'node:fs/promises';
import { join, normalize } from 'node:path';
import { createClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

const root = join(process.cwd(), '.storage');

/**
 * Serves the local-development storage driver. Development only — production
 * reads go through Cloudflare with signed access.
 *
 * Still checks ownership: the key's first two segments are u/{userId}, so a
 * signed-in developer cannot fetch another account's objects even locally. Dev
 * shortcuts that skip authorisation are how authorisation gaps reach production.
 */
export async function GET(
  _request: Request,
  { params }: { params: Promise<{ key: string[] }> },
) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Not signed in' }, { status: 401 });

  const { key } = await params;
  const objectKey = key.join('/');

  if (key[0] !== 'u' || key[1] !== user.id) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }

  // Normalise and confine to root, so ../ cannot escape the storage directory.
  const path = normalize(join(root, objectKey));
  if (!path.startsWith(root)) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }

  try {
    const body = await readFile(path);
    return new NextResponse(new Uint8Array(body), {
      headers: {
        'Content-Type': 'image/webp',
        'Cache-Control': 'private, max-age=3600',
      },
    });
  } catch {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
}
