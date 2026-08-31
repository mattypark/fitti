/**
 * What we think someone's taste is, as vectors.
 *
 * Deliberately several vectors, not one. Averaging "90s workwear" and "Sandy
 * Liang bows" produces a centroid that means neither, and a feed built from it
 * shows nothing the user recognises. Keeping the interests separate and querying
 * each one is what makes a mixed-taste feed work at all.
 */

export interface Interaction {
  itemId: string;
  type: keyof typeof WEIGHTS;
  at: Date;
  vector: number[];
}

/** Sign matters far more than magnitude here; these get tuned against real data. */
export const WEIGHTS = {
  impression: 0,
  dwell2s: 0.3,
  dwell6s: 0.6,
  tapThrough: 1,
  like: 2,
  save: 2.5,
  addToCloset: 3,
  share: 3,
  clickOut: 5,
  purchase: 8,
  dismiss: -5,
  hideBrand: -8,
} as const;

const SHORT_HALF_LIFE_DAYS = 14;
const LONG_HALF_LIFE_DAYS = 120;

export function normalise(vector: number[]): number[] {
  const length = Math.hypot(...vector);
  return length === 0 ? vector : vector.map((v) => v / length);
}

export function cosine(a: number[], b: number[]): number {
  let dot = 0;
  for (let i = 0; i < Math.min(a.length, b.length); i += 1) dot += a[i] * b[i];
  return dot;
}

function decayed(weight: number, at: Date, now: Date, halfLifeDays: number): number {
  const days = (now.getTime() - at.getTime()) / 86_400_000;
  return weight * 0.5 ** (days / halfLifeDays);
}

function weightedCentroid(
  interactions: Interaction[],
  now: Date,
  halfLifeDays: number,
): number[] | null {
  const positive = interactions.filter((i) => WEIGHTS[i.type] > 0);
  if (!positive.length) return null;

  const dimensions = positive[0].vector.length;
  const sum = new Array<number>(dimensions).fill(0);
  let total = 0;

  for (const interaction of positive) {
    const weight = decayed(WEIGHTS[interaction.type], interaction.at, now, halfLifeDays);
    if (weight <= 0) continue;
    for (let i = 0; i < dimensions; i += 1) sum[i] += interaction.vector[i] * weight;
    total += weight;
  }

  return total === 0 ? null : normalise(sum.map((v) => v / total));
}

/**
 * k-means over the positively-weighted items. Small k on purpose: below roughly
 * 30 signals the clusters are fitting noise, so callers fall back to one centroid.
 */
export function centroids(vectors: number[][], k: number, iterations = 12): number[][] {
  if (vectors.length <= k) return vectors.map(normalise);

  // Deterministic seeding — spread picks across the set rather than taking the
  // first k, which on a time-ordered list means "the oldest k".
  const step = Math.floor(vectors.length / k);
  let centres = Array.from({ length: k }, (_, i) => [...vectors[i * step]]);

  for (let pass = 0; pass < iterations; pass += 1) {
    const buckets: number[][][] = Array.from({ length: k }, () => []);

    for (const vector of vectors) {
      let best = 0;
      let bestScore = -Infinity;
      centres.forEach((centre, index) => {
        const score = cosine(vector, centre);
        if (score > bestScore) {
          bestScore = score;
          best = index;
        }
      });
      buckets[best].push(vector);
    }

    centres = centres.map((centre, index) => {
      const bucket = buckets[index];
      if (!bucket.length) return centre; // keep an empty cluster rather than collapsing
      const sum = new Array<number>(centre.length).fill(0);
      for (const vector of bucket) {
        for (let i = 0; i < centre.length; i += 1) sum[i] += vector[i];
      }
      return normalise(sum.map((v) => v / bucket.length));
    });
  }

  return centres;
}

export interface Profile {
  /** Distinct long-term interests. Queried separately, never averaged together. */
  longTerm: number[][];
  /** What they have been into this fortnight. */
  shortTerm: number[] | null;
  /** What they are into right now, this session. */
  session: number[] | null;
  /** Things to steer away from. */
  negative: number[] | null;
  positiveCount: number;
}

export function buildProfile(
  interactions: Interaction[],
  sessionInteractions: Interaction[] = [],
  now = new Date(),
): Profile {
  const positive = interactions.filter((i) => WEIGHTS[i.type] > 0);
  const negatives = interactions.filter((i) => WEIGHTS[i.type] < 0);

  // Below ~30 signals, k-means fits noise rather than taste.
  const k = positive.length >= 30 ? 3 : 1;
  const longTerm = positive.length
    ? centroids(positive.map((i) => normalise(i.vector)), k)
    : [];

  const negativeCentroid = negatives.length
    ? normalise(
        negatives
          .map((i) => i.vector)
          .reduce((sum, v) => sum.map((s, idx) => s + v[idx]), new Array(negatives[0].vector.length).fill(0)),
      )
    : null;

  return {
    longTerm,
    shortTerm: weightedCentroid(interactions, now, SHORT_HALF_LIFE_DAYS),
    session: sessionInteractions.length
      ? weightedCentroid(sessionInteractions, now, LONG_HALF_LIFE_DAYS)
      : null,
    negative: negativeCentroid,
    positiveCount: positive.length,
  };
}
