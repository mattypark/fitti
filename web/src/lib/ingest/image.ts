import sharp from 'sharp';

/** Magic bytes. Content-Type is client-controlled and therefore a suggestion. */
const SIGNATURES: Array<[string, number[]]> = [
  ['image/jpeg', [0xff, 0xd8, 0xff]],
  ['image/png', [0x89, 0x50, 0x4e, 0x47]],
  ['image/webp', [0x52, 0x49, 0x46, 0x46]], // RIFF; WEBP confirmed at offset 8
];

export function sniff(buffer: Buffer): string | null {
  for (const [mime, signature] of SIGNATURES) {
    if (signature.every((byte, index) => buffer[index] === byte)) {
      if (mime === 'image/webp' && buffer.subarray(8, 12).toString() !== 'WEBP') continue;
      return mime;
    }
  }
  // HEIC/HEIF carries an ftyp box at offset 4.
  if (buffer.subarray(4, 8).toString() === 'ftyp') return 'image/heic';
  return null;
}

export interface Derivatives {
  master: Buffer;   // 2048px, no alpha — archival and re-processing source
  preview: Buffer;  // 1024px
  thumb: Buffer;    // 400px, what the grid draws
  width: number;
  height: number;
}

/**
 * Strip, normalise, and derive every size at once.
 *
 * EXIF removal is the important part and it happens here, on the server, before
 * a single byte reaches storage. A closet photo taken at home carries
 * GPSLatitude/GPSLongitude — the user's home address — plus a capture timestamp
 * that maps their routine. Client-side stripping is advisory; a modified client
 * simply skips it.
 *
 * Two traps: sharp drops all metadata on output by default, so `.withMetadata()`
 * is exactly wrong here and is deliberately absent. And `.rotate()` with no
 * argument BAKES IN the EXIF orientation — it must run before the metadata is
 * dropped, or every portrait photo lands sideways.
 */
export async function derive(input: Buffer): Promise<Derivatives> {
  // limitInputPixels defuses decompression bombs: a small file that expands to
  // hundreds of megapixels and takes the process with it.
  const base = sharp(input, { limitInputPixels: 50_000_000 }).rotate();
  const metadata = await base.metadata();

  const [master, preview, thumb] = await Promise.all([
    base.clone().resize(2048, 2048, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 82 }).toBuffer(),
    base.clone().resize(1024, 1024, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 78 }).toBuffer(),
    base.clone().resize(400, 400, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 75 }).toBuffer(),
  ]);

  return {
    master,
    preview,
    thumb,
    width: metadata.width ?? 0,
    height: metadata.height ?? 0,
  };
}

/** Proves the strip worked. Used by the ingest test rather than trusted blindly. */
export async function hasLocationData(buffer: Buffer): Promise<boolean> {
  const metadata = await sharp(buffer).metadata();
  return Boolean(metadata.exif);
}
