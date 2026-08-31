import type { Conditions, Garment, Outfit, Slot } from './types';

/**
 * Build outfits from what someone actually owns.
 *
 * Deliberately deterministic. A language model writes the one-line "why" on top of
 * this, but it never picks the clothes: the model has no idea what is clean, what
 * was worn yesterday, or what the weather is, and it will happily suggest a
 * garment the user does not own. Filter and score first, narrate second.
 */

const REQUIRED: Slot[] = ['top', 'bottom', 'footwear'];

/** Neutrals go with everything, so hue distance is meaningless below this. */
const NEUTRAL_CHROMA = 0.04;

export function weatherFilter(garments: Garment[], conditions: Conditions): Garment[] {
  return garments.filter((garment) => {
    if (conditions.raining && garment.covers.includes('footwear') && garment.waterproof === false) {
      return false;
    }
    // Warmth is a band, not a threshold: a parka is as wrong at 85F as a vest is
    // at 20F, and only rejecting "too cold" would dress people in coats in July.
    if (conditions.temperatureF >= 75 && garment.warmth >= 4) return false;
    if (conditions.temperatureF <= 45 && garment.warmth <= 1) return false;
    return true;
  });
}

/**
 * Colour harmony from the hue circle.
 *
 * Analogous (within 40°) and complementary (around 180°) both read as deliberate.
 * The band in between — roughly 60-120° apart — is what looks accidental, and it
 * is the only thing actually penalised here.
 */
export function harmony(a: Garment, b: Garment): number {
  if (a.chroma < NEUTRAL_CHROMA || b.chroma < NEUTRAL_CHROMA) return 1;

  const raw = Math.abs(a.hue - b.hue) % 360;
  const distance = raw > 180 ? 360 - raw : raw;

  if (distance <= 40) return 1;
  if (distance >= 150) return 0.9;
  if (distance >= 60 && distance <= 120) return 0.35;
  return 0.65;
}

/** Two busy patterns fight. One busy piece against solids is a focal point. */
export function patternScore(pieces: Garment[]): number {
  const busy = pieces.filter((piece) => piece.pattern !== 'solid').length;
  if (busy === 0) return 0.85;
  if (busy === 1) return 1;
  return Math.max(0, 0.5 - (busy - 2) * 0.25);
}

/** An outfit should be all one register. Mixing 2 and 5 reads as a mistake. */
export function formalityScore(pieces: Garment[], target?: number): number {
  const levels = pieces.map((p) => p.formality);
  const spread = Math.max(...levels) - Math.min(...levels);
  let score = spread <= 1 ? 1 : Math.max(0, 1 - (spread - 1) * 0.4);

  if (target !== undefined) {
    const mean = levels.reduce((sum, n) => sum + n, 0) / levels.length;
    score *= Math.max(0, 1 - Math.abs(mean - target) * 0.3);
  }
  return score;
}

/**
 * Surfaces pieces the user owns and never wears.
 *
 * This is the single most valuable term here. The loudest complaint about every
 * competitor is that it restyles the same handful of items and ignores the rest of
 * the wardrobe, and that complaint is exactly this term missing.
 */
export function noveltyScore(pieces: Garment[], now = new Date()): number {
  const scores = pieces.map((piece) => {
    if (!piece.lastWornISO) return 1; // never worn — the whole point
    const days = (now.getTime() - new Date(piece.lastWornISO).getTime()) / 86_400_000;
    return Math.min(1, Math.log10(Math.max(days, 1) + 1) / 1.5);
  });
  return scores.reduce((sum, n) => sum + n, 0) / scores.length;
}

export function scoreOutfit(pieces: Garment[], conditions: Conditions, now?: Date): Outfit {
  const reasons: string[] = [];

  let colour = 1;
  for (let i = 0; i < pieces.length; i += 1) {
    for (let j = i + 1; j < pieces.length; j += 1) {
      colour = Math.min(colour, harmony(pieces[i], pieces[j]));
    }
  }

  const pattern = patternScore(pieces);
  const formality = formalityScore(pieces, conditions.occasionFormality);
  const novelty = noveltyScore(pieces, now);

  if (colour >= 0.9) reasons.push('the colours sit together');
  if (pattern < 0.6) reasons.push('two patterns competing');
  if (formality < 0.6) reasons.push('mixed dress codes');
  if (novelty > 0.8) reasons.push('brings back something you never wear');

  const score = colour * 0.35 + pattern * 0.2 + formality * 0.25 + novelty * 0.2;
  return { pieces, score, reasons };
}

/** Every valid combination of one piece per required slot. */
function combinations(garments: Garment[]): Garment[][] {
  const bySlot = new Map<Slot, Garment[]>();
  for (const slot of REQUIRED) {
    bySlot.set(slot, garments.filter((g) => g.covers.includes(slot)));
  }

  const results: Garment[][] = [];

  // A dress covers top and bottom at once, so it forms an outfit with footwear
  // alone. Requiring one piece per slot would silently exclude every dress.
  const dresses = garments.filter(
    (g) => g.covers.includes('top') && g.covers.includes('bottom'),
  );
  const shoes = bySlot.get('footwear') ?? [];

  for (const dress of dresses) {
    for (const shoe of shoes) results.push([dress, shoe]);
  }

  for (const top of bySlot.get('top') ?? []) {
    if (top.covers.includes('bottom')) continue; // already handled as a dress
    for (const bottom of bySlot.get('bottom') ?? []) {
      if (bottom.covers.includes('top')) continue;
      for (const shoe of shoes) results.push([top, bottom, shoe]);
    }
  }

  return results;
}

export function buildOutfits(
  garments: Garment[],
  conditions: Conditions,
  limit = 3,
  now?: Date,
): Outfit[] {
  const eligible = weatherFilter(garments, conditions);
  const scored = combinations(eligible)
    .map((pieces) => scoreOutfit(pieces, conditions, now))
    .sort((a, b) => b.score - a.score);

  // Don't return three variations on one shirt — that is the loudest complaint
  // about every competitor. But a small closet genuinely cannot produce three
  // wholly separate outfits, and returning one suggestion because the wardrobe is
  // small is worse than returning three that share a piece.
  //
  // So: take everything that differs substantially first, then top up from what
  // is left, best-scoring first.
  const chosen: Outfit[] = [];

  const overlapsTooMuch = (candidate: Outfit) =>
    chosen.some((picked) => {
      const pickedIds = new Set(picked.pieces.map((p) => p.id));
      const shared = candidate.pieces.filter((p) => pickedIds.has(p.id)).length;
      return shared > candidate.pieces.length / 2;
    });

  for (const outfit of scored) {
    if (chosen.length >= limit) break;
    if (overlapsTooMuch(outfit)) continue;
    chosen.push(outfit);
  }

  for (const outfit of scored) {
    if (chosen.length >= limit) break;
    const alreadyPicked = chosen.some(
      (picked) =>
        picked.pieces.length === outfit.pieces.length &&
        picked.pieces.every((p, i) => p.id === outfit.pieces[i].id),
    );
    if (!alreadyPicked) chosen.push(outfit);
  }

  return chosen;
}
