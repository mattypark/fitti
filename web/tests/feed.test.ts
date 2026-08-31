import { test } from 'node:test';
import assert from 'node:assert/strict';

import { buildProfile, cosine, normalise, WEIGHTS, type Interaction } from '../src/lib/feed/profile.ts';
import { rankFeed, popularity, affinity, freshness, type Candidate } from '../src/lib/feed/rank.ts';

const DAY = 86_400_000;

/** Unit vectors in a small space, so similarity is easy to reason about. */
const AXES = {
  workwear: normalise([1, 0, 0]),
  bows: normalise([0, 1, 0]),
  running: normalise([0, 0, 1]),
  betweenWorkwearBows: normalise([1, 1, 0]),
};

function interaction(vector: number[], type: Interaction['type'], daysAgo = 0): Interaction {
  return { itemId: Math.random().toString(36), type, at: new Date(Date.now() - daysAgo * DAY), vector };
}

function candidate(over: Partial<Candidate> & { id: string; vector: number[] }): Candidate {
  return {
    listedAt: new Date(), impressions: 100, engagements: 5, pool: 'test', ...over,
  };
}

test('two separate tastes stay separate instead of averaging into neither', () => {
  const interactions = [
    ...Array.from({ length: 18 }, () => interaction(AXES.workwear, 'like')),
    ...Array.from({ length: 18 }, () => interaction(AXES.bows, 'like')),
  ];
  const profile = buildProfile(interactions);
  assert.equal(profile.longTerm.length, 3, 'enough signal for clustering');

  const workwearItem = candidate({ id: 'w', vector: AXES.workwear });
  const middleItem = candidate({ id: 'm', vector: AXES.betweenWorkwearBows });

  // The whole point: a real interest must beat the average of two interests.
  assert.ok(
    affinity(workwearItem, profile) > affinity(middleItem, profile),
    'averaging the centroids would have scored the middle item highest',
  );
});

test('a small amount of signal uses one centroid rather than fitting noise', () => {
  const profile = buildProfile(Array.from({ length: 5 }, () => interaction(AXES.workwear, 'like')));
  assert.equal(profile.longTerm.length, 1);
});

test('recent interest outweighs old interest', () => {
  const profile = buildProfile([
    interaction(AXES.running, 'like', 1),
    interaction(AXES.workwear, 'like', 200),
  ]);
  assert.ok(profile.shortTerm);
  assert.ok(
    cosine(profile.shortTerm!, AXES.running) > cosine(profile.shortTerm!, AXES.workwear),
    'a like from 200 days ago should not outweigh yesterday',
  );
});

test('dismissals push away rather than being ignored', () => {
  const profile = buildProfile([
    interaction(AXES.workwear, 'like'),
    interaction(AXES.running, 'dismiss'),
  ]);
  assert.ok(profile.negative);
  assert.ok(cosine(profile.negative!, AXES.running) > 0.9);
});

test('popularity is smoothed, so a lucky first click is not a hit', () => {
  const lucky = candidate({ id: 'lucky', vector: AXES.workwear, impressions: 3, engagements: 1 });
  const proven = candidate({ id: 'proven', vector: AXES.workwear, impressions: 1000, engagements: 200 });
  assert.ok(popularity(lucky) < popularity(proven));
  assert.ok(popularity(lucky) < 0.15, 'one click in three views is not a 33% item');
});

test('freshness fades rather than dominating', () => {
  const now = new Date();
  const brandNew = candidate({ id: 'new', vector: AXES.workwear, listedAt: now });
  const lastWeek = candidate({ id: 'old', vector: AXES.workwear, listedAt: new Date(now.getTime() - 7 * DAY) });
  assert.ok(freshness(brandNew, now) > freshness(lastWeek, now));
  assert.ok(freshness(lastWeek, now) < 0.4);
});

test('a page never exceeds the brand and category caps', () => {
  const profile = buildProfile([interaction(AXES.workwear, 'like')]);
  const candidates = Array.from({ length: 60 }, (_, i) =>
    candidate({
      id: `i${i}`,
      vector: normalise([1, i / 60, (i % 7) / 10]),
      brand: i < 30 ? 'Carhartt' : `Brand${i}`,
      category: i % 2 === 0 ? 'outerwear' : `cat${i}`,
      sellerId: `seller${i % 9}`,
    }),
  );

  const page = rankFeed(candidates, profile, 20);
  const brands = new Map<string, number>();
  const categories = new Map<string, number>();
  for (const item of page) {
    brands.set(item.brand!, (brands.get(item.brand!) ?? 0) + 1);
    categories.set(item.category!, (categories.get(item.category!) ?? 0) + 1);
  }
  assert.ok(Math.max(...brands.values()) <= 3, 'brand cap exceeded');
  assert.ok(Math.max(...categories.values()) <= 6, 'category cap exceeded');
});

test('no two neighbouring items are near-duplicates', () => {
  const profile = buildProfile([interaction(AXES.workwear, 'like')]);
  // Deliberately full of near-identical vectors.
  const candidates = Array.from({ length: 40 }, (_, i) =>
    candidate({ id: `i${i}`, vector: normalise([1, 0.001 * i, 0]), brand: `B${i}`, category: `C${i}` }),
  );

  const page = rankFeed(candidates, profile, 12);
  for (let i = 1; i < page.length; i += 1) {
    const similarity = cosine(page[i].vector, page[i - 1].vector);
    assert.ok(similarity <= 0.92, `positions ${i - 1} and ${i} are ${similarity} similar`);
  }
});

test('exploration lands in fixed, measurable slots', () => {
  const profile = buildProfile(Array.from({ length: 10 }, () => interaction(AXES.workwear, 'like')));
  // A graded catalogue rather than two clusters: real inventory shades between
  // tastes, and a hard binary would let diversity re-ranking alternate perfectly
  // on its own, leaving exploration nothing to do.
  const candidates = Array.from({ length: 40 }, (_, i) =>
    candidate({
      id: `i${i}`,
      vector: normalise([1 - i / 45, (i % 5) / 10, i / 45]),
      brand: `B${i}`,
      category: `C${i}`,
    }),
  );

  const page = rankFeed(candidates, profile, 20);
  assert.deepEqual(
    page.filter((item) => item.isExplore).map((item) => item.position),
    [3, 10, 18],
    'exploration must be measurable, so it is positional',
  );
});

test('explore slots are less familiar than the rest of the page', () => {
  const profile = buildProfile(Array.from({ length: 10 }, () => interaction(AXES.workwear, 'like')));
  const candidates = Array.from({ length: 40 }, (_, i) =>
    candidate({
      id: `i${i}`,
      vector: normalise([1 - i / 45, (i % 5) / 10, i / 45]),
      brand: `B${i}`,
      category: `C${i}`,
    }),
  );

  const page = rankFeed(candidates, profile, 20);
  const mean = (items: typeof page) =>
    items.reduce((sum, item) => sum + affinity(item, profile), 0) / items.length;

  assert.ok(
    mean(page.filter((i) => i.isExplore)) < mean(page.filter((i) => !i.isExplore)),
    'explore slots were no less familiar than the rest of the page',
  );
});

test('a brand-new user still gets a full page', () => {
  const profile = buildProfile([]);
  const candidates = Array.from({ length: 40 }, (_, i) =>
    candidate({ id: `i${i}`, vector: normalise([i % 5, i % 3, i % 7]), brand: `B${i}`, category: `C${i}` }),
  );
  assert.equal(rankFeed(candidates, profile, 20).length, 20);
});

test('positions are contiguous from zero', () => {
  const profile = buildProfile([interaction(AXES.workwear, 'like')]);
  const candidates = Array.from({ length: 30 }, (_, i) =>
    candidate({ id: `i${i}`, vector: normalise([i % 4, i % 6, i % 5]), brand: `B${i}`, category: `C${i}` }),
  );
  const page = rankFeed(candidates, profile, 15);
  assert.deepEqual(page.map((i) => i.position), Array.from({ length: 15 }, (_, i) => i));
});

test('negative weights are actually negative', () => {
  assert.ok(WEIGHTS.dismiss < 0 && WEIGHTS.hideBrand < 0);
  assert.ok(WEIGHTS.purchase > WEIGHTS.like);
});
