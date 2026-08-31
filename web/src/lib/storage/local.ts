import 'server-only';

import { mkdir, writeFile, unlink } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import type { StorageDriver } from './index';

/**
 * Filesystem driver for local development, so the pipeline is testable with no
 * Cloudflare account. Files land in .storage/, which is gitignored.
 *
 * Deliberately NOT a production path: it serves through a route handler with no
 * CDN and no signing, and it does not exist on a serverless filesystem.
 */
const root = join(process.cwd(), '.storage');

export const localDisk: StorageDriver = {
  async put(key, body) {
    const path = join(root, key);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, body);
  },

  async signedUrl(key) {
    return `/api/local-storage/${key}`;
  },

  async delete(key) {
    await unlink(join(root, key)).catch(() => {});
  },
};
