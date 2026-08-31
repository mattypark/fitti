import { cosine, type Profile } from './profile.ts';

export interface Candidate {
  id: string;
  vector: number[];
  brand?: string;
  sellerId?: string;
  category?: string;
  listedAt: Date;
  impressions: number;
  engagements: number;
  /** Which retrieval pool produced it, kept for measuring pool quality later. */
  pool: string;
}

export interface RankedItem extends Candidate {
  score: number;
  isExplore: boolean;
  position: number;
}

/** Exploration goes in fixed slots so its effect is measurable. */
const EXPLORE_SLOTS = new Set([3, 10, 18]);

const CAPS = { seller: 2, brand: 3, category: 6 } as const;
/** Two neighbours this similar look like a duplicate listing. */
const ADJACENT_SIMILARITY_CEILING = 0.92;
/** Relevance vs variety. Pure relevance produces a page of the same jacket. */
const MMR_LAMBDA = 0.75;

/** Bayesian-smoothed rate, so three impressions and one like isn't a 33% winner. */
export function popularity(item: Candidate, priorRate = 0.05, priorWeight = 20): number {
  return (item.engagements + priorWeight * priorRate) / (item.impressions + priorWeight);
}

/** A one-week time constant. Freshness is a tiebreaker, not a driver. */
export function freshness(item: Candidate, now: Date): number {
  const hours = (now.getTime() - item.listedAt.getTime()) / 3_600_000;
  return Math.exp(-hours / 168);
}

/**
 * The best-matching interest, never the average of them.
 *
 * This one line is why a mixed-taste feed works: a workwear jacket should score
 * on the workwear centroid alone and not be dragged down by an unrelated one.
 */
export function affinity(item: Candidate, profile: Profile): number {
  if (!profile.longTerm.length) return 0;
  return Math.max(...profile.longTerm.map((centroid) => cosine(item.vector, centroid)));
}

export function baseScore(item: Candidate, profile: Profile, now: Date): number {
  const sessionWeight = profile.session
    ? 0.5 * Math.min(1, (profile.positiveCount || 1) / 10)
    : 0;

  let score =
    1.0 * affinity(item, profile) +
    sessionWeight * (profile.session ? cosine(item.vector, profile.session) : 0) +
    0.25 * popularity(item) +
    0.2 * freshness(item, now);

  if (profile.shortTerm) score += 0.5 * cosine(item.vector, profile.shortTerm);
  if (profile.negative) score -= 0.6 * Math.max(0, cosine(item.vector, profile.negative));

  return score;
}

/**
 * Rank, diversify, and reserve the exploration slots.
 *
 * Diversity is not a nicety. Ranking purely by relevance returns twenty near
 * copies of one jacket, which reads as a broken feed, and it starves the profile
 * of the varied signal it needs to improve.
 */
export function rankFeed(
  candidates: Candidate[],
  profile: Profile,
  pageSize = 20,
  now = new Date(),
): RankedItem[] {
  const scored = candidates
    .map((item) => ({ ...item, score: baseScore(item, profile, now) }))
    .sort((a, b) => b.score - a.score);

  const page: RankedItem[] = [];
  const counts = { seller: new Map<string, number>(), brand: new Map<string, number>(), category: new Map<string, number>() };

  const within = (map: Map<string, number>, key: string | undefined, cap: number) =>
    key === undefined || (map.get(key) ?? 0) < cap;

  const take = (item: Candidate & { score: number }, isExplore: boolean) => {
    page.push({ ...item, isExplore, position: page.length });
    for (const [field, map] of [
      ['sellerId', counts.seller],
      ['brand', counts.brand],
      ['category', counts.category],
    ] as const) {
      const key = item[field];
      if (key !== undefined) map.set(key, (map.get(key) ?? 0) + 1);
    }
  };

  const used = new Set<string>();

  while (page.length < pageSize) {
    const slot = page.length;
    const wantsExplore = EXPLORE_SLOTS.has(slot);

    const eligible = scored.filter((item) => {
      if (used.has(item.id)) return false;
      if (!within(counts.seller, item.sellerId, CAPS.seller)) return false;
      if (!within(counts.brand, item.brand, CAPS.brand)) return false;
      if (!within(counts.category, item.category, CAPS.category)) return false;

      const previous = page[page.length - 1];
      if (previous && cosine(item.vector, previous.vector) > ADJACENT_SIMILARITY_CEILING) {
        return false;
      }
      return true;
    });

    if (!eligible.length) break;

    if (wantsExplore) {
      // Deliberately the least personally-relevant ELIGIBLE item. An exploration
      // slot filled with something already predicted to be liked explores nothing.
      //
      // Eligibility still applies, so the adjacent-similarity rule can leave a
      // slot with nothing unfamiliar to offer — two off-taste items in a row are
      // often near-duplicates of each other. That is the right precedence:
      // a visibly repetitive feed costs more than one missed exploration.
      const explore = eligible.reduce((worst, item) =>
        affinity(item, profile) < affinity(worst, profile) ? item : worst,
      );
      used.add(explore.id);
      take(explore, true);
      continue;
    }

    // Maximal Marginal Relevance: relevance, minus similarity to what is already
    // on the page.
    const best = eligible.reduce((winner, item) => {
      const penalty = (candidate: typeof item) =>
        page.length === 0
          ? 0
          : Math.max(...page.map((chosen) => cosine(candidate.vector, chosen.vector)));
      const value = (candidate: typeof item) =>
        MMR_LAMBDA * candidate.score - (1 - MMR_LAMBDA) * penalty(candidate);
      return value(item) > value(winner) ? item : winner;
    });

    used.add(best.id);
    take(best, false);
  }

  return page;
}
