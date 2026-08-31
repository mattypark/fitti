import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  buildOutfits, harmony, patternScore, formalityScore, noveltyScore, weatherFilter,
} from '../src/lib/outfits/engine.ts';
import type { Garment } from '../src/lib/outfits/types.ts';

function piece(over: Partial<Garment> & { id: string }): Garment {
  return {
    name: over.id, covers: ['top'], hue: 85, chroma: 0.1, pattern: 'solid',
    formality: 3, warmth: 3, timesWorn: 5, ...over,
  };
}

test('neutrals go with anything', () => {
  const black = piece({ id: 'black', chroma: 0.01, hue: 0 });
  const loud = piece({ id: 'loud', chroma: 0.2, hue: 300 });
  assert.equal(harmony(black, loud), 1);
});

test('analogous and complementary both read as deliberate; the middle does not', () => {
  const base = piece({ id: 'base', hue: 30, chroma: 0.15 });
  assert.equal(harmony(base, piece({ id: 'near', hue: 55, chroma: 0.15 })), 1);
  assert.ok(harmony(base, piece({ id: 'opposite', hue: 205, chroma: 0.15 })) >= 0.85);
  assert.ok(harmony(base, piece({ id: 'awkward', hue: 120, chroma: 0.15 })) < 0.5);
});

test('hue distance wraps around the circle', () => {
  const a = piece({ id: 'a', hue: 350, chroma: 0.15 });
  const b = piece({ id: 'b', hue: 20, chroma: 0.15 });
  assert.equal(harmony(a, b), 1, '350 and 20 are 30 apart, not 330');
});

test('one pattern is a focal point, two is a fight', () => {
  const solid = piece({ id: 's' });
  const striped = piece({ id: 'st', pattern: 'striped' });
  const floral = piece({ id: 'f', pattern: 'floral' });
  assert.ok(patternScore([solid, striped]) > patternScore([solid, solid]));
  assert.ok(patternScore([striped, floral]) < 0.6);
});

test('mixed dress codes are penalised', () => {
  assert.equal(formalityScore([piece({ id: 'a', formality: 3 }), piece({ id: 'b', formality: 3 })]), 1);
  assert.ok(formalityScore([piece({ id: 'a', formality: 1 }), piece({ id: 'b', formality: 5 })]) < 0.3);
});

test('never-worn pieces score highest — this is the anti-rut term', () => {
  const never = noveltyScore([piece({ id: 'never' })]);
  const yesterday = noveltyScore([
    piece({ id: 'recent', lastWornISO: new Date(Date.now() - 86_400_000).toISOString() }),
  ]);
  assert.equal(never, 1);
  assert.ok(yesterday < 0.5, 'something worn yesterday should not be suggested again');
});

test('warmth is a band — a parka is as wrong in summer as a vest is in winter', () => {
  const parka = piece({ id: 'parka', warmth: 5 });
  const vest = piece({ id: 'vest', warmth: 1 });

  const hot = weatherFilter([parka, vest], { temperatureF: 88 });
  assert.deepEqual(hot.map((g) => g.id), ['vest']);

  const cold = weatherFilter([parka, vest], { temperatureF: 30 });
  assert.deepEqual(cold.map((g) => g.id), ['parka']);
});

test('rain rules out shoes known not to survive it', () => {
  const suede = piece({ id: 'suede', covers: ['footwear'], waterproof: false });
  const boots = piece({ id: 'boots', covers: ['footwear'], waterproof: true });
  const dry = weatherFilter([suede, boots], { temperatureF: 60 });
  const wet = weatherFilter([suede, boots], { temperatureF: 60, raining: true });
  assert.equal(dry.length, 2);
  assert.deepEqual(wet.map((g) => g.id), ['boots']);
});

test('a dress makes an outfit with shoes alone', () => {
  const outfits = buildOutfits(
    [
      piece({ id: 'dress', covers: ['top', 'bottom'] }),
      piece({ id: 'shoes', covers: ['footwear'] }),
    ],
    { temperatureF: 65 },
  );
  assert.equal(outfits.length, 1);
  assert.deepEqual(outfits[0].pieces.map((p) => p.id).sort(), ['dress', 'shoes']);
});

test('suggestions do not repeat the same pieces', () => {
  const garments = [
    piece({ id: 't1', covers: ['top'] }),
    piece({ id: 't2', covers: ['top'], hue: 200 }),
    piece({ id: 'b1', covers: ['bottom'] }),
    piece({ id: 'b2', covers: ['bottom'], hue: 210 }),
    piece({ id: 's1', covers: ['footwear'] }),
    piece({ id: 's2', covers: ['footwear'], hue: 220 }),
  ];
  const outfits = buildOutfits(garments, { temperatureF: 65 }, 3);
  assert.equal(outfits.length, 3, 'a small closet should still yield three options');

  // No two suggestions may be the same set of pieces.
  const keys = outfits.map((o) => o.pieces.map((p) => p.id).sort().join('+'));
  assert.equal(new Set(keys).size, 3, 'duplicate outfit returned');

  // And the top two must differ substantially, not by a single shoe swap.
  const [first, second] = outfits.map((o) => new Set(o.pieces.map((p) => p.id)));
  const shared = [...first].filter((id) => second.has(id)).length;
  assert.ok(shared <= 1, `top two suggestions share ${shared} pieces`);
});

test('a large closet gives fully independent suggestions', () => {
  const garments = Array.from({ length: 12 }, (_, i) =>
    piece({
      id: `g${i}`,
      covers: [(['top', 'bottom', 'footwear'] as const)[i % 3]],
      hue: (i * 30) % 360,
    }),
  );
  const outfits = buildOutfits(garments, { temperatureF: 65 }, 3);
  assert.equal(outfits.length, 3);

  const seen = new Set<string>();
  for (const outfit of outfits) {
    const ids = outfit.pieces.map((p) => p.id);
    assert.ok(ids.some((id) => !seen.has(id)), 'a suggestion added nothing new');
    ids.forEach((id) => seen.add(id));
  }
});

test('an empty closet yields nothing rather than throwing', () => {
  assert.deepEqual(buildOutfits([], { temperatureF: 65 }), []);
});
