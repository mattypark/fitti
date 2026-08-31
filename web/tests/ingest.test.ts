import { test } from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';

import { derive, sniff, hasLocationData } from '../src/lib/ingest/image.ts';

/**
 * The claim in docs/DECISIONS.md is that a photo's location metadata never
 * reaches storage. A closet photo taken at home carries the user's home address
 * in GPSLatitude. That is a testable claim, so it is tested.
 */

/** A JPEG carrying EXIF, including GPS coordinates. */
async function photoWithLocation(): Promise<Buffer> {
  return sharp({
    create: { width: 800, height: 1200, channels: 3, background: { r: 200, g: 170, b: 90 } },
  })
    .withExif({
      IFD0: { Make: 'Apple', Model: 'iPhone 17 Pro' },
      IFD2: { GPSLatitude: '37/1 46/1 2976/100', GPSLongitude: '122/1 25/1 1080/100' },
    })
    .jpeg()
    .toBuffer();
}

test('the source photo really does carry metadata', async () => {
  const original = await photoWithLocation();
  assert.equal(await hasLocationData(original), true,
    'fixture has no EXIF, so the strip test below would pass vacuously');
});

test('derived images carry no metadata at all', async () => {
  const original = await photoWithLocation();
  const { master, preview, thumb } = await derive(original);

  for (const [name, buffer] of Object.entries({ master, preview, thumb })) {
    assert.equal(await hasLocationData(buffer), false,
      `${name} still carries EXIF — this is the user's home address`);
  }
});

test('orientation is baked in before metadata is dropped', async () => {
  // Orientation 6 means "rotate 90°". If .rotate() did not run first, the output
  // would keep its original 800x1200 shape and every portrait photo would land
  // sideways once the tag was gone.
  const rotated = await sharp({
    create: { width: 800, height: 1200, channels: 3, background: { r: 10, g: 10, b: 10 } },
  })
    // withExif does not set the orientation tag — sharp reports 1 back.
    // withMetadata({orientation}) is what actually writes it.
    .withMetadata({ orientation: 6 })
    .jpeg()
    .toBuffer();

  const { master } = await derive(rotated);
  const meta = await sharp(master).metadata();
  assert.ok(meta.width && meta.height, 'derived image should have dimensions');
  assert.ok(meta.width > meta.height, 'orientation was not applied before the strip');
});

test('derivative sizes match the documented ladder', async () => {
  const { master, preview, thumb } = await derive(await photoWithLocation());
  const sizes = await Promise.all([master, preview, thumb].map((b) => sharp(b).metadata()));

  assert.equal(Math.max(sizes[0].width!, sizes[0].height!), 1200, 'master caps at 2048, no upscaling');
  assert.equal(Math.max(sizes[1].width!, sizes[1].height!), 1024);
  assert.equal(Math.max(sizes[2].width!, sizes[2].height!), 400);

  // Every rung is smaller than the one above it, which is the only reason to
  // generate more than one.
  assert.ok(thumb.byteLength < preview.byteLength);
  assert.ok(preview.byteLength < master.byteLength);
});

test('file type comes from magic bytes, not the declared type', async () => {
  const jpeg = await photoWithLocation();
  assert.equal(sniff(jpeg), 'image/jpeg');

  const png = await sharp(jpeg).png().toBuffer();
  assert.equal(sniff(png), 'image/png');

  // A text file renamed .jpg must not pass.
  assert.equal(sniff(Buffer.from('#!/bin/sh\nrm -rf /')), null);
});
