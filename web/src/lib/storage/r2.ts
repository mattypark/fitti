import 'server-only';

import { AwsClient } from 'aws4fetch';
import { config } from '@/lib/config';
import type { StorageDriver } from './index';

/**
 * Cloudflare R2 over its S3-compatible API.
 *
 * aws4fetch rather than the AWS SDK: it is a few kilobytes and does the one thing
 * needed here, which keeps a serverless function's cold start honest.
 */
function client() {
  return new AwsClient({
    accessKeyId: config.r2.accessKeyId!,
    secretAccessKey: config.r2.secretAccessKey!,
    service: 's3',
    region: 'auto',
  });
}

function endpoint(key: string) {
  return `https://${config.r2.accountId}.r2.cloudflarestorage.com/${config.r2.bucket}/${key}`;
}

export const r2: StorageDriver = {
  async put(key, body, contentType) {
    const response = await client().fetch(endpoint(key), {
      method: 'PUT',
      body: new Uint8Array(body),
      headers: { 'Content-Type': contentType },
    });
    if (!response.ok) {
      throw new Error(`R2 rejected the upload (${response.status})`);
    }
  },

  async signedUrl(key, expiresInSeconds) {
    // Presigned URLs only work against the S3 endpoint, not a custom domain.
    const url = new URL(endpoint(key));
    url.searchParams.set('X-Amz-Expires', String(expiresInSeconds));
    const signed = await client().sign(new Request(url, { method: 'GET' }), {
      aws: { signQuery: true },
    });
    return signed.url;
  },

  async delete(key) {
    await client().fetch(endpoint(key), { method: 'DELETE' });
  },
};
