import 'server-only';

import { config } from '@/lib/config';
import { r2 } from './r2';
import { localDisk } from './local';

export interface StorageDriver {
  put(key: string, body: Buffer, contentType: string): Promise<void>;
  /** A URL the client can fetch. Short-lived; these are private photos. */
  signedUrl(key: string, expiresInSeconds: number): Promise<string>;
  delete(key: string): Promise<void>;
}

/**
 * R2 when it is configured, the local filesystem when it is not, so the whole
 * ingest pipeline runs end to end on a laptop with no cloud account.
 */
export const storage: StorageDriver = config.hasR2 ? r2 : localDisk;

/**
 * Object keys are DERIVED from the verified session, never accepted from the
 * client. A client-supplied path is an IDOR by construction; making the key a
 * pure function of (user, garment, variant) removes the category of bug rather
 * than guarding against it.
 */
export function objectKey(userId: string, garmentId: string, variant: string, ext: string) {
  return `u/${userId}/g/${garmentId}/${variant}.${ext}`;
}
